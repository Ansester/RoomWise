package fitcheck

import androidx.compose.runtime.*
import androidx.compose.material3.*
import androidx.compose.foundation.layout.*
import androidx.compose.ui.unit.dp
import androidx.compose.ui.text.input.PasswordVisualTransformation
import kotlinx.coroutines.*
import java.io.File

private fun loadLaptopLocalCredentials(): Map<String, String> {
    val candidates = listOfNotNull(
        System.getProperty("roomwise.config")?.takeIf { it.isNotBlank() }?.let(::File),
        System.getenv("ROOMWISE_CONFIG_PATH")?.takeIf { it.isNotBlank() }?.let(::File),
        File(System.getProperty("user.dir"), "config.local.properties"),
        System.getProperty("user.home")?.let { File(it, "RoomWise/config.local.properties") }
    ).distinctBy { it.absolutePath }
    val file = candidates.firstOrNull { it.isFile } ?: return emptyMap()
    return runCatching {
        file.useLines { lines ->
            lines.map(String::trim)
                .filter { it.isNotEmpty() && !it.startsWith("#") && '=' in it }
                .mapNotNull { line ->
                    val (rawKey, rawValue) = line.split('=', limit = 2)
                    val key = rawKey.trim()
                    val value = rawValue.trim().removeSurrounding("\"").removeSurrounding("'").trim()
                    if (key in setOf("GROQ_API_KEY", "GROQ_MODEL", "TAVILY_API_KEY") && value.isNotEmpty()) key to value else null
                }
                .toMap()
        }
    }.getOrDefault(emptyMap())
}

class RuntimeConfig(
    environment: Map<String, String> = System.getenv(),
    localCredentials: Map<String, String> = loadLaptopLocalCredentials()
) {
    private val initialLlmKey = environment["GROQ_API_KEY"]?.trim()?.takeIf { it.isNotEmpty() }
        ?: environment["FITCHECK_LLM_KEY"]?.trim()?.takeIf { it.isNotEmpty() }
        ?: localCredentials["GROQ_API_KEY"].orEmpty()
    var provider by mutableStateOf(
        environment["FITCHECK_PROVIDER"]?.trim()?.lowercase()?.takeIf { it in listOf("fixture", "local", "groq") }
            ?: "fixture"
    )
    var model by mutableStateOf(
        environment["GROQ_MODEL"]?.trim()?.takeIf { it.isNotEmpty() }
            ?: environment["FITCHECK_MODEL"]?.trim()?.takeIf { it.isNotEmpty() }
            ?: localCredentials["GROQ_MODEL"]?.takeIf { it.isNotBlank() } ?: "openai/gpt-oss-20b"
    )
    var llmKey by mutableStateOf(initialLlmKey)
    var tavilyKey by mutableStateOf(
        environment["TAVILY_API_KEY"]?.trim()?.takeIf { it.isNotEmpty() }
            ?: environment["FITCHECK_TAVILY_KEY"]?.trim()?.takeIf { it.isNotEmpty() }
            ?: localCredentials["TAVILY_API_KEY"].orEmpty()
    )
}
@Composable fun ConnectionDialog(c:RuntimeConfig,dismiss:()->Unit) {
    AlertDialog(onDismissRequest=dismiss,title={Text("Desktop connections")},text={Column(verticalArrangement=Arrangement.spacedBy(8.dp)) {
        Text("Sample mode needs no account or key. For optional live search, use your own Tavily and Groq free-plan keys. Each account has quotas; RoomWise does not subscribe to or upgrade any plan.")
        OutlinedTextField(c.provider,{c.provider=it.trim().lowercase()},label={Text("Parser: fixture / local / groq")})
        OutlinedTextField(c.model,{c.model=it.trim()},label={Text("Groq model ID")})
        OutlinedTextField(c.llmKey,{c.llmKey=it.trim()},label={Text("Groq key (optional for local parsing)")},visualTransformation=PasswordVisualTransformation())
        OutlinedTextField(c.tavilyKey,{c.tavilyKey=it.trim()},label={Text("Tavily search key")},visualTransformation=PasswordVisualTransformation())
        Text("Keys stay in memory for this session unless you supplied your own ignored config.local.properties file. Environment values take precedence. Live search sends the request to Tavily and, with Groq selected, to Groq; room geometry is not sent. Sample mode never calls either provider.")
    }},confirmButton={Button(onClick=dismiss) {Text("Done")}},dismissButton={TextButton(onClick={c.llmKey="";c.tavilyKey=""}) {Text("Clear keys")}})
}
data class StoreResult(val products:List<Product>,val status:String)
class ShoppingSession(val room:Room,val saved:Boolean,val config:RuntimeConfig,val log:(String)->Unit,
    val onStore:(String,StoreResult)->Unit,val onPreview:(String,Pose)->Unit) {
    suspend fun run(prompt:String):Preferences {
        require(Regex("chair|كرسي",RegexOption.IGNORE_CASE).containsMatchIn(prompt)) {"Describe a chair request"}
        if(!saved) {
            require(config.tavilyKey.isNotBlank()) {"Configure Tavily"}
            val tools=ShoppingTools(room,TavilyProvider(config.tavilyKey),log,onStore,onPreview)
            require(config.provider in listOf("fixture", "local", "groq")) {"Select local or Groq parsing"}
            if(config.provider=="groq") {
                require(config.llmKey.isNotBlank() && config.model.isNotBlank())
                log("Started Koog shopping agent (Groq)")
                try {GroqShoppingAgent(config.llmKey,config.model).run(prompt,tools)}
                catch(_:TimeoutCancellationException) {log("Agent time limit reached; completing bounded retailer retrieval")}
                catch(e:CancellationException) {throw e}
                catch(_:Exception) {log("Groq unavailable or quota reached; using local parsing and preserving results")}
            }
            if(tools.preferences==null) {
                val fallback=parseFixtureRequest(prompt)
                tools.set_preferences(kotlinx.serialization.json.Json.encodeToString(Preferences.serializer(),fallback))
                log("Used limited local request parser; verify displayed preferences")
            }
            tools.read_room_summary()
            tools.finishRetrieval()
            return tools.preferences!!
        }
        val request=parseFixtureRequest(prompt)
        log("Parsed demo request using fixture parser (no LLM)")
        for(store in listOf("Amazon UAE","Noon UAE","Temu")) {
            delay(100)
            val p=demoProducts().filter {it.retailer==store}
            onStore(store,StoreResult(p,"Saved fixture"));log("Loaded $store fixture")
            p.filter {it.previewSize()==null}.forEach {log("Dimensions missing: ${it.title}")}
        }
        return request
    }
}
