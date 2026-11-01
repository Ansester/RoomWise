package fitcheck

import kotlinx.serialization.Serializable

@Serializable data class Point(val x: Double, val z: Double)
@Serializable data class Dimensions(val width: Double, val depth: Double, val height: Double) {
    fun valid() = listOf(width, depth, height).all { it.isFinite() && it > 0 && it <= 100 }
}
@Serializable data class Pose(val x: Double = 0.0, val z: Double = 0.0, val yaw: Double = 0.0)
@Serializable data class RoomElement(
    val id: String, val kind: String, val dimensions: Dimensions, val pose: Pose,
    val transform: List<Double> = emptyList()
)
@Serializable data class Room(
    val schemaVersion: Int = 1, val units: String = "m",
    val coordinates: String = "right-handed:Y-up:floor-XZ:yaw-X-toward-Z",
    val name: String, val capturedAt: String,
    val walls: List<RoomElement> = emptyList(), val openings: List<RoomElement> = emptyList(),
    val objects: List<RoomElement> = emptyList(), val boundary: List<Point> = emptyList(),
    val boundaryComplete: Boolean = false, val savedDemo: Boolean = false
)
// USER_ENTERED records a person's listing details; it must never imply that a
// retailer API retrieved or independently verified the supplied facts.
@Serializable enum class ProductProvenance { FIXTURE, LIVE, SAVED_LIVE, USER_ENTERED }
@Serializable enum class ScanQuality { COMPLETE, PARTIAL, UNUSABLE }

@Serializable enum class EvidenceStatus { SUPPORTED, UNSUPPORTED, UNKNOWN }
@Serializable data class Feature(val name: String, val status: EvidenceStatus, val source: String = "")
@Serializable data class SizeEvidence(val size: Dimensions, val source: String, val origin: String = "listing", val kind: String = "assembled", val unit: String = "m")
@Serializable data class Product(
    val id: String, val retailer: String, val title: String, val url: String,
    val imageUrl: String? = null, val price: Double? = null, val currency: String? = null,
    val retrievedAt: String, val variant: String? = null, val seller: String? = null,
    val dimensions: SizeEvidence? = null, val features: List<Feature> = emptyList(),
    val delivery: String? = null, val availability: String? = null,
    val issues: List<String> = emptyList(), val source: String = "", val savedDemo: Boolean = false,
    val provenance: ProductProvenance = if (savedDemo) ProductProvenance.FIXTURE else ProductProvenance.LIVE
)
@Serializable data class Preferences(
    val category: String = "chair", val budget: Double? = null, val currency: String = "AED",
    val colour: String? = null, val requiredFeatures: List<String> = emptyList(),
    val preferredFeatures: List<String> = emptyList(), val maxWidth: Double? = null,
    val maxDepth: Double? = null, val unknowns: List<String> = emptyList()
)
fun metres(value: Double, unit: String): Double {
    require(value.isFinite() && value > 0) { "Dimension must be positive and finite" }
    return value * when (unit.lowercase()) { "m" -> 1.0; "cm" -> .01; "mm" -> .001; "in", "inch", "inches" -> .0254; else -> error("Unsupported unit") }
}
fun Product.previewSize(): Dimensions? = dimensions?.takeIf { it.kind == "assembled" && it.unit == "m" && it.source.isNotBlank() && it.size.valid() }?.size
fun budgetStatus(p: Product, request: Preferences): EvidenceStatus = when {
    request.budget == null -> EvidenceStatus.SUPPORTED
    p.price == null || p.currency != request.currency -> EvidenceStatus.UNKNOWN
    !p.price.isFinite() || p.price < 0 -> EvidenceStatus.UNKNOWN
    p.price <= request.budget -> EvidenceStatus.SUPPORTED
    else -> EvidenceStatus.UNSUPPORTED
}
