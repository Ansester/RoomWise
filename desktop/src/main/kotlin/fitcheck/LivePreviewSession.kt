package fitcheck

import com.sun.net.httpserver.HttpExchange
import com.sun.net.httpserver.HttpServer
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import java.net.Inet4Address
import java.net.InetAddress
import java.net.InetSocketAddress
import java.net.NetworkInterface
import java.security.MessageDigest
import java.security.SecureRandom
import java.util.concurrent.Executors

@Serializable
data class LivePreviewState(
    val schemaVersion: Int = 1,
    val revision: Long = 0,
    val products: List<Product> = emptyList(),
    val selectedProductId: String? = null
)

@Serializable private data class SelectionRequest(val productId: String)

/** Explicit, temporary LAN sharing. It never publishes rooms, chat history or provider keys. */
class LivePreviewSession(private val onSelection: (String) -> Unit = {}) : AutoCloseable {
    private val lock = Any()
    private val json = Json { encodeDefaults = true; ignoreUnknownKeys = false }
    private var state = LivePreviewState()
    private var server: HttpServer? = null
    private var executor: java.util.concurrent.ExecutorService? = null
    private var token: String? = null

    val running: Boolean get() = synchronized(lock) { server != null }

    /** Passing loopback is useful for tests. The UI deliberately binds the trusted LAN. */
    fun start(bindAddress: InetAddress? = null): List<String> = synchronized(lock) {
        check(server == null) { "Pairing is already active" }
        val freshToken = ByteArray(16).also(SecureRandom()::nextBytes).joinToString("") { "%02x".format(it) }
        val fresh = HttpServer.create(InetSocketAddress(bindAddress, 0), 8)
        val pool = Executors.newFixedThreadPool(2) { work -> Thread(work, "RoomWise-local-preview").apply { isDaemon = true } }
        fresh.executor = pool
        fresh.createContext("/") { exchange -> handle(exchange, freshToken) }
        token = freshToken
        server = fresh
        executor = pool
        fresh.start()
        val addresses = if (bindAddress != null) listOf(bindAddress.hostAddress) else localAddresses()
        addresses.map { "http://$it:${fresh.address.port}/session/$freshToken" }
    }

    fun publish(products: List<Product>, selectedProductId: String?) = synchronized(lock) {
        val bounded = products.distinctBy { it.id }.take(50)
        val selected = selectedProductId?.takeIf { id -> bounded.any { it.id == id } }
        if (bounded != state.products || selected != state.selectedProductId) {
            state = state.copy(revision = state.revision + 1, products = bounded, selectedProductId = selected)
        }
    }

    fun snapshot(): LivePreviewState = synchronized(lock) { state }

    override fun close() = synchronized(lock) {
        token = null
        server?.stop(0)
        server = null
        executor?.shutdownNow()
        executor = null
    }

    private fun handle(exchange: HttpExchange, sessionToken: String) {
        try {
            val peer = exchange.remoteAddress.address
            if (!peer.isLoopbackAddress && !peer.isSiteLocalAddress) {
                respond(exchange, 403, "{\"error\":\"Local network required\"}")
                return
            }
            val path = exchange.requestURI.rawPath
            val parts = path.split('/')
            val presented = parts.getOrNull(2).orEmpty()
            val valid = synchronized(lock) {
                token == sessionToken && parts.getOrNull(1) == "session" &&
                    MessageDigest.isEqual(presented.toByteArray(), sessionToken.toByteArray())
            }
            if (!valid || exchange.requestURI.rawQuery != null) {
                respond(exchange, 404, "{\"error\":\"Session unavailable\"}")
                return
            }
            if (parts.size == 3 && exchange.requestMethod == "GET") {
                respond(exchange, 200, json.encodeToString(snapshot()))
                return
            }
            if (parts.size == 4 && parts[3] == "selection" && exchange.requestMethod == "POST") {
                // A paired native client has no Origin. Reject browser-origin mutations.
                if (exchange.requestHeaders.getFirst("Origin") != null) {
                    respond(exchange, 403, "{\"error\":\"Native pairing client required\"}")
                    return
                }
                val contentLength = exchange.requestHeaders.getFirst("Content-Length")?.toLongOrNull()
                if (contentLength != null && contentLength > 4096) {
                    respond(exchange, 413, "{\"error\":\"Request too large\"}")
                    return
                }
                val body = exchange.requestBody.use { it.readNBytes(4097) }
                if (body.size > 4096) {
                    respond(exchange, 413, "{\"error\":\"Request too large\"}")
                    return
                }
                val id = runCatching { json.decodeFromString<SelectionRequest>(body.toString(Charsets.UTF_8)).productId }.getOrNull()
                var changed = false
                val accepted = synchronized(lock) {
                    if (id == null || state.products.none { it.id == id }) false
                    else {
                        if (state.selectedProductId != id) {
                            state = state.copy(revision = state.revision + 1, selectedProductId = id)
                            changed = true
                        }
                        true
                    }
                }
                if (!accepted) {
                    respond(exchange, 400, "{\"error\":\"Unknown product\"}")
                    return
                }
                if (changed) onSelection(id!!)
                respond(exchange, 200, json.encodeToString(snapshot()))
                return
            }
            respond(exchange, if (parts.size == 3 || (parts.size == 4 && parts[3] == "selection")) 405 else 404, "{\"error\":\"Unsupported request\"}")
        } catch (_: Exception) {
            // Never print session URLs, bearer tokens, request bodies or credentials.
            runCatching { respond(exchange, 400, "{\"error\":\"Invalid request\"}") }
        } finally {
            exchange.close()
        }
    }

    private fun respond(exchange: HttpExchange, status: Int, body: String) {
        val bytes = body.toByteArray(Charsets.UTF_8)
        exchange.responseHeaders.set("Content-Type", "application/json; charset=utf-8")
        exchange.responseHeaders.set("Cache-Control", "no-store")
        exchange.responseHeaders.set("X-Content-Type-Options", "nosniff")
        exchange.sendResponseHeaders(status, bytes.size.toLong())
        exchange.responseBody.use { it.write(bytes) }
    }

    private fun localAddresses(): List<String> = runCatching {
        NetworkInterface.getNetworkInterfaces().toList().filter { it.isUp && !it.isLoopback }
            .flatMap { it.inetAddresses.toList() }
            .filterIsInstance<Inet4Address>()
            .filter { it.isSiteLocalAddress }
            .map { it.hostAddress }.distinct()
    }.getOrDefault(emptyList()).ifEmpty { listOf("127.0.0.1") }
}
