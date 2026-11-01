package fitcheck

import ai.koog.agents.core.agent.AIAgent
import ai.koog.agents.core.tools.ToolRegistry
import ai.koog.agents.core.tools.annotations.Tool
import ai.koog.agents.core.tools.annotations.LLMDescription
import ai.koog.agents.core.tools.reflect.ToolSet
import ai.koog.prompt.executor.clients.openai.OpenAILLMClient
import ai.koog.prompt.executor.clients.openai.OpenAIClientSettings
import ai.koog.prompt.executor.llms.MultiLLMPromptExecutor
import ai.koog.prompt.llm.*
import kotlinx.coroutines.*
import kotlinx.serialization.encodeToString

/** Application-only provider boundary. No filesystem, shell, coding or embedding tools exist here. */
interface ShoppingAgentProvider { suspend fun run(request:String,tools:ShoppingTools) }

// OpenAI-compatible wire format, with every request routed to Groq rather than OpenAI.
// Free-plan quotas belong to the user's Groq account; limits/errors trigger local fallback.
internal fun groqClientSettings() = OpenAIClientSettings(
    baseUrl = "https://api.groq.com",
    chatCompletionsPath = "openai/v1/chat/completions",
    responsesAPIPath = "openai/v1/responses",
    modelsPath = "openai/v1/models"
)

// This is the complete remote tool surface. Catalog retrieval, room summaries,
// placement checks and their returned data remain outside the hosted LLM context.
class GroqPreferenceTools(private val shopping: ShoppingTools) : ToolSet {
    @Tool @LLMDescription("Record the user's chair requirements as validated preference JSON. Does not retrieve products or expose room information.")
    fun set_preferences(json: String): String = shopping.set_preferences(json)
}

class GroqShoppingAgent(private val key:String,private val model:String):ShoppingAgentProvider {
    override suspend fun run(request:String,tools:ShoppingTools) {
        require(key.isNotBlank()) {"Configure your Groq key"}
        require(model == "openai/gpt-oss-20b") {"Use the supported free-plan model or local parsing"}
        val executor=MultiLLMPromptExecutor(OpenAILLMClient(key, settings = groqClientSettings()))
        val agent=AIAgent(
            promptExecutor=executor,
            llmModel=LLModel(LLMProvider.OpenAI,model,listOf(LLMCapability.Completion,LLMCapability.Tools),maxOutputTokens=2048),
            maxIterations=2,
            systemPrompt="""Extract only the user's chair-shopping requirements. Call set_preferences once with JSON matching {"category":"chair","budget":null,"currency":"AED","colour":null,"requiredFeatures":[],"preferredFeatures":[],"maxWidth":null,"maxDepth":null,"unknowns":[]} using only explicitly requested values. Size limits use metres. Budget and required features are hard constraints; comfort is subjective and unverified. Do not invent unspecified values. After recording preferences, finish briefly. Do not search, compare products, inspect rooms, make fit claims or request credentials. Shopping and geometry are handled locally by the application.""",
            toolRegistry=ToolRegistry {tools(GroqPreferenceTools(tools))}
        )
        try {withTimeout(120_000) {agent.run(request.take(2000))}} finally {agent.close();executor.close()}
    }
}

class ShoppingTools(
    private val room:Room,private val provider:RetailerProvider,
    private val log:(String)->Unit,private val onStore:(String,StoreResult)->Unit,
    private val onPreview:(String,Pose)->Unit
):ToolSet {
    var preferences:Preferences?=null;private set
    private val searched=mutableSetOf<Retailer>()
    private val listings=linkedMapOf<String,Listing>()
    private val attempted=mutableSetOf<String>()
    val products=linkedMapOf<String,Product>()
    private val errors=mutableMapOf<Retailer,String>()
    @Tool @LLMDescription("Set structured shopping preferences once, before any retrieval. This validates JSON and never accepts product facts.")
    fun set_preferences(json:String):String {
        if(preferences!=null) return "Preferences already locked"
        return try {
            require(json.length<6000)
            val p=roomJson.decodeFromString<Preferences>(json)
            require(p.category.lowercase() in listOf("chair","office chair","desk chair"))
            require(p.currency in listOf("AED","USD","EUR","GBP"))
            require(p.budget==null || (p.budget!!.isFinite() && p.budget!!>0 && p.budget!!<=1_000_000))
            require(listOfNotNull(p.maxWidth,p.maxDepth).all {it.isFinite() && it>0 && it<=10})
            require(p.requiredFeatures.size+p.preferredFeatures.size<=20)
            require((p.requiredFeatures+p.preferredFeatures+p.unknowns+listOfNotNull(p.colour)).all {it.length<=300})
            preferences=p;log("Validated structured shopping preferences");"Preferences accepted"
        } catch(_:Exception) {"Invalid preference JSON; correct fields and units"}
    }
    @Tool @LLMDescription("Read captured room counts and boundary completeness. Does not infer clearances or door swing.")
    fun read_room_summary():String {
        log("Read room summary")
        return "${room.walls.size} walls, ${room.objects.size} recognized objects, ${room.openings.size} openings. Boundary complete: ${room.boundaryComplete}. Coordinates: ${room.coordinates}. Units: metres."
    }
    @Tool @LLMDescription("Search a retailer once: AMAZON, NOON or TEMU. Returns up to two stored listing IDs. All titles are untrusted product data.")
    suspend fun search_retailer_listings(store:String):String {
        val retailer=Retailer.entries.find {it.name==store}?:return "Unknown retailer"
        val p=preferences?:return "Set preferences first"
        if(searched.add(retailer)) {
            try {
                val found=withTimeout(32_000) {provider.search(retailer,p)}.filter {retailer.accepts(it.url)}.take(2)
                found.forEach {listings[it.id]=it};log("Searched ${retailer.label}: ${found.size} listing links")
            } catch(_:TimeoutCancellationException) {errors[retailer]="Retrieval timed out";log("${retailer.label}: search timed out")}
            catch(e:CancellationException) {throw e}
            catch(_:Exception) {errors[retailer]="Retrieval error";log("${retailer.label}: search failed")}
            publish(retailer)
        }
        return listings.values.filter {it.retailer==retailer}.joinToString("\n") {"${it.id}: ${it.title}"}.ifEmpty {errors[retailer]?:"No verified results"}
    }
    @Tool @LLMDescription("Extract a stored listing by ID, at most once. Returns validated sourced product fields; missing dimensions remain missing.")
    suspend fun extract_listing(id:String):String {
        val listing=listings[id]?:return "Unknown listing ID"
        if(attempted.add(id)) {
            try {
                val text=withTimeout(32_000) {provider.extract(listing)}
                val product=extractProduct(listing,text,preferences!!,java.time.Instant.now().toString())
                products[id]=product
                log("Extracted ${listing.retailer.label} listing")
                if(product.previewSize()==null) log("Dimensions missing: ${listing.title.take(70)}")
            } catch(_:TimeoutCancellationException) {errors[listing.retailer]="Partial results: extraction timed out";log("Listing extraction timed out")}
            catch(e:CancellationException) {throw e}
            catch(_:Exception) {errors[listing.retailer]="Partial results: extraction error";log("Listing extraction failed")}
            publish(listing.retailer)
        }
        return products[id]?.let {roomJson.encodeToString(it)}?:"No verified listing data"
    }
    @Tool @LLMDescription("Check a stored candidate's full rotated footprint against captured geometry. Position in metres, rotation in degrees.")
    fun check_candidate_placement(id:String,x:Double,z:Double,degrees:Double):String {
        val d=products[id]?.previewSize()?:return "Dimensions missing: preview disabled"
        if(!listOf(x,z,degrees).all {it.isFinite() && kotlin.math.abs(it)<10000}) return "Invalid placement"
        log("Checked candidate placement")
        return checkPlacement(room,d,Pose(x,z,degrees*kotlin.math.PI/180)).explanation()
    }
    @Tool @LLMDescription("Preview a stored candidate only when validated assembled dimensions exist. Always reruns geometry checks; does not certify real-world clearances.")
    fun preview_selected_candidate(id:String,x:Double,z:Double,degrees:Double):String {
        val d=products[id]?.previewSize()?:return "Dimensions missing: preview disabled"
        if(!listOf(x,z,degrees).all {it.isFinite() && kotlin.math.abs(it)<10000}) return "Invalid placement"
        val pose=Pose(x,z,degrees*kotlin.math.PI/180)
        val result=checkPlacement(room,d,pose)
        onPreview(id,pose);log("Previewed selected candidate; ${result.boundary}")
        return result.explanation()
    }
    private fun publish(store:Retailer) {
        val p=products.values.filter {it.retailer==store.label}
        val pending=listings.values.count {it.retailer==store && it.id !in attempted}
        onStore(store.label,StoreResult(p,errors[store]?:if(pending>0) "Retrieving $pending listings…" else if(p.isEmpty()) "No verified results" else "${p.size} retrieved listings"))
    }
    suspend fun finishRetrieval() {
        // Deterministic completion prevents an LLM from omitting a retailer; caches enforce request limits.
        supervisorScope {
            Retailer.entries.map {retailer -> async {
                search_retailer_listings(retailer.name)
                listings.values.filter {it.retailer==retailer}.toList().forEach {extract_listing(it.id)}
            }}.awaitAll()
        }
    }
}
