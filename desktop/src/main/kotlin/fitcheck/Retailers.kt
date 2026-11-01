package fitcheck

import kotlinx.coroutines.*
import kotlinx.serialization.json.*
import java.net.URI
import java.net.http.*
import java.time.Duration
import java.time.Instant
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

interface RetailerProvider {
    suspend fun search(store:Retailer,request:Preferences):List<Listing>
    suspend fun extract(listing:Listing):String
}
class TavilyProvider(private val key:String):RetailerProvider {
    private val http=HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(10)).followRedirects(HttpClient.Redirect.NEVER).build()
    private suspend fun post(endpoint:String,body:JsonObject):JsonObject = withTimeout(30_000) {
        require(key.isNotBlank()) {"Tavily key required"}
        val request=HttpRequest.newBuilder(URI("https://api.tavily.com/$endpoint"))
            .timeout(Duration.ofSeconds(25)).header("Content-Type","application/json")
            .header("Authorization","Bearer $key").POST(HttpRequest.BodyPublishers.ofString(body.toString())).build()
        val response=suspendCancellableCoroutine<HttpResponse<java.io.InputStream>> { c ->
            val future=http.sendAsync(request,HttpResponse.BodyHandlers.ofInputStream())
            c.invokeOnCancellation {future.cancel(true)}
            future.whenComplete {r,e -> if(e!=null) {if(c.isActive)c.resumeWithException(IllegalStateException("Retrieval failed"))} else if(c.isActive) c.resume(r) else r.body().close() }
        }
        response.body().use { input ->
            check(response.statusCode() in 200..299) {"Retrieval HTTP ${response.statusCode()}"}
            val bytes=runInterruptible(Dispatchers.IO) {input.readNBytes(2_000_001)}
            check(bytes.size<=2_000_000) {"Response too large"}
            Json.parseToJsonElement(bytes.decodeToString()).jsonObject
        }
    }
    override suspend fun search(store:Retailer,request:Preferences):List<Listing> {
        val query=listOfNotNull(request.colour,request.category,request.requiredFeatures.joinToString(" "),request.budget?.let {"under ${request.currency} $it"},"UAE assembled dimensions").joinToString(" ").take(500)
        val response=post("search",buildJsonObject {
            put("query",query);put("max_results",4);put("search_depth","basic");put("auto_parameters",false);put("topic","general")
            put("country","united arab emirates");put("include_answer",false);put("include_raw_content",false);put("include_images",true)
            putJsonArray("include_domains") {add(store.domain)}
        })
        return response["results"]?.jsonArray.orEmpty().mapNotNull { value ->
            val o=value.jsonObject;val url=o.string("url")?:return@mapNotNull null
            if(!store.accepts(url)) return@mapNotNull null
            val title=o.string("title")?:return@mapNotNull null
            if(!Regex("chair|كرسي",RegexOption.IGNORE_CASE).containsMatchIn(title+" "+o.string("content"))) return@mapNotNull null
            val image=(o["images"] as? JsonArray)?.firstOrNull()?.let { if(it is JsonPrimitive) it.contentOrNull else (it as? JsonObject)?.string("url") }?.takeIf {it.startsWith("https://")}
            Listing("${store.name}-${url.hashCode()}",store,title.take(300),url,o.string("content").orEmpty().take(6000),image)
        }.distinctBy {it.url}.take(2)
    }
    override suspend fun extract(listing:Listing):String {
        require(listing.retailer.accepts(listing.url))
        // Parse only the snippet already returned by basic search. Never silently
        // spend extra credits on extraction; missing facts remain unknown in the UI.
        return listing.snippet.take(6000).takeIf {it.isNotBlank()} ?: error("No search snippet")
    }
}
private fun JsonObject.string(key:String)=(get(key) as? JsonPrimitive)?.contentOrNull
/** Isolated store failures never discard successful store results. */
suspend fun retrieveStores(provider:RetailerProvider,request:Preferences,onStore:(String,StoreResult)->Unit) = supervisorScope {
    Retailer.entries.map { store -> async {
        val products=mutableListOf<Product>()
        try {
            withTimeout(70_000) {
                val listings=provider.search(store,request)
                for(listing in listings) {
                    try {products.add(extractProduct(listing,provider.extract(listing),request,Instant.now().toString()))}
                    catch(e:CancellationException) {throw e}
                    catch(_:Exception) { /* Continue other candidates; do not invent product facts. */ }
                    onStore(store.label,StoreResult(products.toList(),"Retrieving…"))
                }
            }
            onStore(store.label,StoreResult(products.toList(),if(products.isEmpty()) "No verified results" else "${products.size} retrieved listings"))
        } catch(_:TimeoutCancellationException) {onStore(store.label,StoreResult(products.toList(),"Retrieval timed out"))}
        catch(e:CancellationException) {throw e}
        catch(_:Exception) {onStore(store.label,StoreResult(products.toList(),"Retrieval error"))}
    } }.awaitAll()
}
