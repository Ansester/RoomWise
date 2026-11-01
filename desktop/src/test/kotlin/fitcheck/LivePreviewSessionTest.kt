package fitcheck

import kotlinx.serialization.json.Json
import java.net.InetAddress
import java.net.URI
import java.net.http.HttpClient
import java.net.http.HttpRequest
import java.net.http.HttpResponse
import java.util.concurrent.atomic.AtomicReference
import kotlin.test.*

class LivePreviewSessionTest {
    private val client = HttpClient.newHttpClient()
    private fun get(url: String) = client.send(HttpRequest.newBuilder(URI(url)).GET().build(), HttpResponse.BodyHandlers.ofString())
    private fun post(url: String, body: String, origin: String? = null): HttpResponse<String> {
        val request = HttpRequest.newBuilder(URI("$url/selection")).POST(HttpRequest.BodyPublishers.ofString(body))
        origin?.let { request.header("Origin", it) }
        return client.send(request.build(), HttpResponse.BodyHandlers.ofString())
    }

    @Test fun publishesListingAndAcceptsBidirectionalSelection() {
        val received = AtomicReference<String>()
        LivePreviewSession(received::set).use { host ->
            val products = demoProducts()
            host.publish(products, products.first().id)
            val url = host.start(InetAddress.getByName("127.0.0.1")).single()
            val initial = get(url)
            assertEquals(200, initial.statusCode())
            val state = Json.decodeFromString<LivePreviewState>(initial.body())
            assertEquals(products, state.products)
            assertEquals(products.first().id, state.selectedProductId)
            val changed = post(url, "{\"productId\":\"${products[1].id}\"}")
            assertEquals(200, changed.statusCode())
            val update = Json.decodeFromString<LivePreviewState>(changed.body())
            assertEquals(products[1].id, update.selectedProductId)
            assertEquals(products[1].id, received.get())
            assertTrue(update.revision > state.revision)
            host.publish(products, products[1].id)
            assertEquals(update.revision, host.snapshot().revision)
            assertNull(initial.headers().firstValue("Access-Control-Allow-Origin").orElse(null))
        }
    }

    @Test fun rejectsUnknownTokensProductsAndOversizedOrBrowserRequests() {
        LivePreviewSession().use { host ->
            host.publish(demoProducts(), null)
            val url = host.start(InetAddress.getByName("127.0.0.1")).single()
            assertEquals(404, get(url.dropLast(1) + if (url.last() == '0') '1' else '0').statusCode())
            assertEquals(400, post(url, "{\"productId\":\"missing\"}").statusCode())
            assertEquals(413, post(url, "x".repeat(4097)).statusCode())
            assertEquals(403, post(url, "{}", "https://example.com").statusCode())
            assertEquals(405, get("$url/selection").statusCode())
            assertEquals(404, get("$url?anything=1").statusCode())
        }
    }

    @Test fun stopDisablesOldSessionAndRestartRotatesToken() {
        val host = LivePreviewSession()
        val first = host.start(InetAddress.getByName("127.0.0.1")).single()
        host.close()
        assertFalse(host.running)
        val second = host.start(InetAddress.getByName("127.0.0.1")).single()
        assertNotEquals(first.substringAfter("/session/"), second.substringAfter("/session/"))
        val oldTokenAtNewPort = second.substringBefore("/session/") + "/session/" + first.substringAfter("/session/")
        assertEquals(404, get(oldTokenAtNewPort).statusCode())
        host.close()
    }
}
