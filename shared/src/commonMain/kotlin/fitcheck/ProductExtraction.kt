package fitcheck

import kotlinx.serialization.Serializable

@Serializable
enum class Retailer(val label: String, val domain: String) {
    AMAZON("Amazon UAE", "amazon.ae"),
    NOON("Noon UAE", "noon.com"),
    TEMU("Temu", "temu.com");

    fun accepts(url: String): Boolean = runCatching {
        if (url.any { it.isWhitespace() || it.isISOControl() || it == '\\' }) return false
        val match = Regex("^https://([^/?#@:]+)(/[^?#]*)?(?:\\?[^#]*)?(?:#.*)?$", RegexOption.IGNORE_CASE).matchEntire(url) ?: return false
        val host = match.groupValues[1].lowercase()
        val path = match.groupValues[2]
        val validHost = host.split('.').all { Regex("[a-z0-9](?:[a-z0-9-]*[a-z0-9])?").matches(it) }
        validHost && (host == domain || host.endsWith(".$domain")) && when (this) {
            AMAZON -> Regex("/(?:dp|gp/product)/[A-Z0-9]{10}(?:[/?]|$)", RegexOption.IGNORE_CASE).containsMatchIn(path + "/")
            NOON -> path.startsWith("/uae-en/") && Regex("/p(?:/|$)").containsMatchIn(path)
            TEMU -> Regex("(?:-g-\\d+|/goods\\.html)").containsMatchIn(path)
        }
    }.getOrDefault(false)
}

@Serializable
data class Listing(
    val id: String,
    val retailer: Retailer,
    val title: String,
    val url: String,
    val snippet: String,
    val imageUrl: String? = null
)

fun parseFixtureRequest(text: String): Preferences {
    val lower = text.lowercase()
    val budget = Regex("(?:under|below|budget|up to)\\s*(?:aed\\s*)?(\\d+(?:\\.\\d+)?)", RegexOption.IGNORE_CASE).find(text)?.groupValues?.get(1)?.toDoubleOrNull()
    return Preferences(
        budget = budget,
        colour = listOf("black", "white", "grey", "blue", "red").firstOrNull { it in lower },
        requiredFeatures = if ("armrest" in lower && "without armrest" !in lower) listOf("armrests") else emptyList(),
        preferredFeatures = if ("comfortable" in lower) listOf("comfort") else emptyList(),
        unknowns = listOf("Fixture parser supports the demo phrase only; verify preferences. Comfort is subjective and unverified.")
    )
}

fun parseLabelledSize(text: String): Dimensions? {
    if (Regex("packag|carton|shipping|box dimensions", RegexOption.IGNORE_CASE).containsMatchIn(text)) return null
    fun value(label: String): Double? {
        val all = Regex("\\b$label\\s*[:=]?\\s*(\\d+(?:\\.\\d+)?)\\s*(cm|mm|m|inches|inch|in)\\b", RegexOption.IGNORE_CASE).findAll(text).toList()
        if (all.size != 1) return null
        return runCatching { metres(all[0].groupValues[1].toDouble(), all[0].groupValues[2]) }.getOrNull()
    }
    val w = value("width") ?: return null
    val d = value("depth") ?: return null
    val h = value("height") ?: return null
    return Dimensions(w, d, h).takeIf { it.valid() }
}

/** Conservative extraction: ambiguous facts are withheld, never invented by an LLM. */
fun extractProduct(listing: Listing, text: String, request: Preferences, retrievedAt: String = "2026-09-20T00:00:00Z"): Product {
    val issues = mutableListOf<String>()
    val lines = text.lines().map { it.trim() }.filter { it.isNotBlank() }
    val priceMatches = Regex("\\bAED\\s*([0-9][0-9,]*(?:\\.[0-9]{1,2})?)\\b", RegexOption.IGNORE_CASE).findAll(text).toList()
    val prices = priceMatches.mapNotNull { it.groupValues[1].replace(",", "").toDoubleOrNull() }.filter { it.isFinite() && it >= 0 }.distinct()
    val price = prices.singleOrNull()
    if (prices.size > 1) issues.add("Conflicting AED prices; selected offer price unknown")
    if (price == null && prices.isEmpty()) issues.add("No explicit AED price extracted")
    val sizeLines = lines.filter {
        Regex("assembled|product dimensions|overall dimensions", RegexOption.IGNORE_CASE).containsMatchIn(it) &&
            !Regex("packag|carton|shipping|box dimensions", RegexOption.IGNORE_CASE).containsMatchIn(it)
    }
    val sizes = sizeLines.mapNotNull { line -> parseLabelledSize(line)?.let { SizeEvidence(it, line) } }.distinctBy { it.size }
    val size = sizes.singleOrNull()
    if (sizes.size > 1) issues.add("Conflicting assembled dimensions; verify selected variant")
    if (size == null) issues.add("Assembled dimensions missing or ambiguous; enter manually")
    fun explicit(label: String): String? = lines.mapNotNull {
        Regex("^${Regex.escape(label)}\\s*[:：]\\s*(.{1,160})$", RegexOption.IGNORE_CASE).matchEntire(it)?.groupValues?.get(1)
    }.distinct().singleOrNull()
    val variant = explicit("Model") ?: explicit("Model number")
    val requested = (request.requiredFeatures + request.preferredFeatures + listOfNotNull(request.colour)).distinct()
    val features = requested.map { feature ->
        val evidence = when (feature.lowercase()) {
            "armrests" -> lines.filter { Regex("^(?:armrests?|armrest type)\\s*:", RegexOption.IGNORE_CASE).containsMatchIn(it) }.distinct().singleOrNull()
            "black", "white", "grey", "blue", "red" -> lines.filter { Regex("^(?:color|colour)\\s*:", RegexOption.IGNORE_CASE).containsMatchIn(it) }.distinct().singleOrNull()
            else -> null
        }
        val state = if (evidence == null) EvidenceStatus.UNKNOWN else when {
            feature == "armrests" && Regex("\\b(no|none|without)\\b", RegexOption.IGNORE_CASE).containsMatchIn(evidence) -> EvidenceStatus.UNSUPPORTED
            feature == "armrests" && Regex("\\b(yes|fixed|adjustable|padded|flip.up)\\b", RegexOption.IGNORE_CASE).containsMatchIn(evidence) -> EvidenceStatus.SUPPORTED
            feature != "armrests" && evidence.substringAfter(":").trim().equals(feature, true) -> EvidenceStatus.SUPPORTED
            else -> EvidenceStatus.UNKNOWN
        }
        Feature(feature, state, evidence.orEmpty())
    }
    issues.add("Verify selected variant and current offer on retailer page. Listings are compared as alternatives, not identical products.")
    return Product(
        listing.id, listing.retailer.label, listing.title, listing.url, listing.imageUrl, price,
        if (price != null) "AED" else null,
        retrievedAt, variant, explicit("Sold by"), size, features, explicit("Delivery cost"),
        explicit("Availability"), issues,
        (priceMatches.map { it.value } + sizeLines + features.map { it.source } + listOf(text.take(3500))).filter { it.isNotBlank() }.distinct().joinToString("\n").take(7000)
    )
}
