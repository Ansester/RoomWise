package fitcheck

import kotlin.math.*
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

val roomJson = Json { prettyPrint = true; encodeDefaults = true; ignoreUnknownKeys = false }
private const val EPS = 1e-8
private const val MAX_BOUNDARY_POINTS = 2000
fun footprint(d: Dimensions, p: Pose): List<Point> = listOf(
    Point(-d.width/2, -d.depth/2), Point(d.width/2, -d.depth/2),
    Point(d.width/2, d.depth/2), Point(-d.width/2, d.depth/2)
).map { Point(p.x + it.x*cos(p.yaw) - it.z*sin(p.yaw), p.z + it.x*sin(p.yaw) + it.z*cos(p.yaw)) }
fun wallEnds(e: RoomElement): List<Point> = listOf(-.5, .5).map {
    Point(e.pose.x + it*e.dimensions.width*cos(e.pose.yaw), e.pose.z + it*e.dimensions.width*sin(e.pose.yaw))
}
private fun cross(a: Point, b: Point, c: Point) = (b.x-a.x)*(c.z-a.z) - (b.z-a.z)*(c.x-a.x)
private fun onEdge(p: Point, a: Point, b: Point) = abs(cross(a,b,p)) < EPS && p.x >= min(a.x,b.x)-EPS && p.x <= max(a.x,b.x)+EPS && p.z >= min(a.z,b.z)-EPS && p.z <= max(a.z,b.z)+EPS
fun inside(p: Point, polygon: List<Point>, includeEdge: Boolean = true): Boolean {
    if (polygon.size < 3) return false
    var result = false
    polygon.indices.forEach { i ->
        val a = polygon[i]; val b = polygon[(i+1)%polygon.size]
        if (onEdge(p,a,b)) return includeEdge
        if ((a.z > p.z) != (b.z > p.z) && p.x < (b.x-a.x)*(p.z-a.z)/(b.z-a.z)+a.x) result = !result
    }
    return result
}
private fun crossing(a: Point,b: Point,c: Point,d: Point) = cross(a,b,c)*cross(a,b,d) < -EPS && cross(c,d,a)*cross(c,d,b) < -EPS
fun overlaps(a: List<Point>, b: List<Point>): Boolean {
    // Separating-axis test on both rotated rectangles. Touching is treated conservatively as overlap.
    for (poly in listOf(a,b)) for (i in poly.indices) {
        val p = poly[i]; val q = poly[(i+1)%poly.size]; val axis = Point(-(q.z-p.z), q.x-p.x)
        val aa = a.map { it.x*axis.x+it.z*axis.z }; val bb = b.map { it.x*axis.x+it.z*axis.z }
        if (aa.max() < bb.min()-EPS || bb.max() < aa.min()-EPS) return false
    }
    return true
}
fun contained(shape: List<Point>, boundary: List<Point>): Boolean {
    if (!shape.all { inside(it,boundary) }) return false
    for (i in shape.indices) for (j in boundary.indices)
        if (crossing(shape[i],shape[(i+1)%shape.size],boundary[j],boundary[(j+1)%boundary.size])) return false
    // A concave notch can enter through a boundary vertex without a proper segment crossing.
    if (boundary.any { inside(it,shape,includeEdge=false) }) return false
    return shape.indices.all { i -> val a=shape[i];val b=shape[(i+1)%shape.size]; inside(Point((a.x+b.x)/2,(a.z+b.z)/2),boundary) }
}
fun Room.scanQuality(): ScanQuality = when {
    boundaryComplete && validPolygon(boundary) -> ScanQuality.COMPLETE
    walls.size >= 2 || objects.isNotEmpty() -> ScanQuality.PARTIAL
    else -> ScanQuality.UNUSABLE
}

fun initialPlacement(room: Room, d: Dimensions? = null): Pose {
    val chairDims = d ?: Dimensions(0.6, 0.6, 1.0)
    if (room.boundaryComplete && validPolygon(room.boundary)) {
        val minX = room.boundary.minOf { it.x }
        val maxX = room.boundary.maxOf { it.x }
        val minZ = room.boundary.minOf { it.z }
        val maxZ = room.boundary.maxOf { it.z }
        val center = Pose((minX + maxX) / 2.0, (minZ + maxZ) / 2.0, 0.0)
        if (checkPlacement(room, chairDims, center).fits) return center
        for (offset in listOf(0.3, -0.3, 0.6, -0.6, 0.9, -0.9)) {
            for (zOff in listOf(0.0, 0.3, -0.3, 0.6, -0.6)) {
                val candidate = Pose(center.x + offset, center.z + zOff, 0.0)
                if (checkPlacement(room, chairDims, candidate).fits) return candidate
            }
        }
        // In a concave room the bounding-box centre may be outside the room. Search
        // the full floor area before falling back to that visible, unconfirmed pose.
        // The grid is bounded and checks actual footprints; it does not promise an
        // optimal placement or infer extra space from a room's bounding rectangle.
        val obstacles = room.objects.filter { it.dimensions.valid() }.map { footprint(it.dimensions, it.pose) }
        for (yaw in listOf(0.0, PI / 2)) {
            val width = if (yaw == 0.0) chairDims.width else chairDims.depth
            val depth = if (yaw == 0.0) chairDims.depth else chairDims.width
            if (maxX - minX < width || maxZ - minZ < depth) continue
            val candidates = (0..16).flatMap { xi -> (0..16).map { zi ->
                Pose(minX + width / 2 + (maxX - minX - width) * xi / 16,
                    minZ + depth / 2 + (maxZ - minZ - depth) * zi / 16, yaw)
            } }.sortedBy { (it.x - center.x).pow(2) + (it.z - center.z).pow(2) }
            for (candidate in candidates) {
                val shape = footprint(chairDims, candidate)
                if (contained(shape, room.boundary) && obstacles.none { overlaps(shape, it) }) return candidate
            }
        }
        return center
    }
    val allPoints = mutableListOf<Point>()
    room.walls.forEach { allPoints.addAll(wallEnds(it)) }
    room.objects.forEach { obj -> allPoints.add(Point(obj.pose.x, obj.pose.z)) }
    if (allPoints.isNotEmpty()) {
        val minX = allPoints.minOf { it.x }
        val maxX = allPoints.maxOf { it.x }
        val minZ = allPoints.minOf { it.z }
        val maxZ = allPoints.maxOf { it.z }
        return Pose((minX + maxX) / 2.0, (minZ + maxZ) / 2.0, 0.0)
    }
    return Pose(2.0, 2.0, 0.0)
}

data class PlacementResult(val boundary: String, val collisions: List<String>, val complete: Boolean) {
    val fits get() = complete && boundary == "Inside scanned boundary" && collisions.isEmpty()
    fun explanation() = listOf(boundary, if (collisions.isEmpty()) "No overlap with recognized objects" else "Overlaps: ${collisions.joinToString()}",
        if (fits) "Dimension footprint fits captured geometry" else "Fit not confirmed",
        "Door swing, chair movement and unrecognized objects are not checked").joinToString(" · ")
}
fun checkPlacement(room: Room, d: Dimensions, p: Pose): PlacementResult {
    require(d.valid() && listOf(p.x,p.z,p.yaw).all { it.isFinite() })
    val box = footprint(d,p)
    val complete = room.boundaryComplete && validPolygon(room.boundary)
    val collisions = room.objects.filter { it.dimensions.valid() && overlaps(box,footprint(it.dimensions,it.pose)) }.map { it.kind }
    return PlacementResult(if (!complete) "Boundary check incomplete (partial scan)" else if (contained(box,room.boundary)) "Inside scanned boundary" else "Outside scanned boundary", collisions, complete)
}
fun validPolygon(p: List<Point>): Boolean {
    if (p.size !in 3..MAX_BOUNDARY_POINTS || p.any { !it.x.isFinite() || !it.z.isFinite() }) return false
    var area = 0.0
    for (i in p.indices) {
        val a=p[i];val b=p[(i+1)%p.size]
        if (hypot(a.x-b.x,a.z-b.z)<EPS) return false
        area += a.x*b.z-b.x*a.z
        for (j in i+1 until p.size) {
            if (j==i+1 || (i==0 && j==p.lastIndex)) continue
            val c=p[j];val d=p[(j+1)%p.size]
            if (crossing(a,b,c,d) || onEdge(a,c,d) || onEdge(b,c,d) || onEdge(c,a,b)) return false
        }
    }
    return abs(area) > .01
}
fun inferBoundary(walls: List<RoomElement>, tolerance: Double = 0.03): List<Point> {
    if (walls.size !in 3..MAX_BOUNDARY_POINTS || !tolerance.isFinite() || tolerance <= 0) return emptyList()
    val endpoints = walls.flatMap(::wallEnds)
    // Every endpoint must have exactly one partner on a different wall. Choosing the
    // nearest of several partners can turn a branching or duplicate scan into a false room.
    val joins = endpoints.indices.map { i ->
        endpoints.indices.filter { j ->
            i / 2 != j / 2 && hypot(endpoints[i].x - endpoints[j].x, endpoints[i].z - endpoints[j].z) < tolerance
        }.singleOrNull() ?: return emptyList()
    }
    val usedWalls = mutableSetOf<Int>()
    val result = mutableListOf<Point>()
    var start = 0
    do {
        if (!usedWalls.add(start / 2)) return emptyList()
        result.add(endpoints[start])
        start = joins[start xor 1]
    } while (start != 0)
    if (usedWalls.size != walls.size) return emptyList()
    return result.takeIf(::validPolygon) ?: emptyList()
}
fun decodeRoom(text: String): Room {
    require(text.length <= 5_000_000) { "Room file too large" }
    val r = roomJson.decodeFromString<Room>(text)
    require(r.schemaVersion==1 && r.units=="m" && r.coordinates=="right-handed:Y-up:floor-XZ:yaw-X-toward-Z") { "Unsupported room schema, units or coordinates" }
    require(r.walls.size+r.objects.size+r.openings.size<=5000)
    (r.walls+r.openings+r.objects).forEach { e ->
        require(listOf(e.pose.x,e.pose.z,e.pose.yaw,e.dimensions.width,e.dimensions.depth,e.dimensions.height).all { it.isFinite() && abs(it)<=1000 }) { "Invalid geometry" }
        require(e.dimensions.width in Double.MIN_VALUE..100.0 && e.dimensions.height in Double.MIN_VALUE..100.0 && e.dimensions.depth in 0.0..100.0) { "Invalid dimensions" }
        require(e.transform.isEmpty() || (e.transform.size==16 && e.transform.all { it.isFinite() }))
        if(e.transform.size==16) {
            require(abs(e.transform[12]-e.pose.x)<.001 && abs(e.transform[14]-e.pose.z)<.001) { "Transform/pose mismatch" }
            val yaw=atan2(e.transform[2],e.transform[0])
            require(abs(sin(yaw-e.pose.yaw))<.001 && cos(yaw-e.pose.yaw)>.999) { "Transform orientation mismatch" }
        }
    }
    require(r.objects.all { it.dimensions.valid() }) { "Object footprint dimensions must be positive" }
    require(r.boundary.size <= MAX_BOUNDARY_POINTS && r.boundary.all { it.x.isFinite() && it.z.isFinite() && abs(it.x) <= 1000 && abs(it.z) <= 1000 }) { "Invalid boundary geometry" }
    require(!r.boundaryComplete || validPolygon(r.boundary)) { "Invalid boundary" }
    if(r.boundaryComplete) return r
    val b=inferBoundary(r.walls)
    return r.copy(boundary=b, boundaryComplete=b.isNotEmpty())
}
// Called by Swift before sharing, so phone exports use the same validation as desktop import.
class RoomBridge {
    fun validate(text: String): String = try {
        if (text.isBlank()) "" else roomJson.encodeToString(decodeRoom(text))
    } catch (_: Throwable) { "" }

    fun safeDecode(text: String): Room? = try {
        if (text.isBlank()) null else decodeRoom(text)
    } catch (_: Throwable) { null }

    fun encodeRoom(room: Room): String = try {
        roomJson.encodeToString(room)
    } catch (_: Throwable) { "" }

    fun encodeProducts(products: List<Product>): String = try {
        roomJson.encodeToString(products)
    } catch (_: Throwable) { "[]" }

    fun decodeProducts(text: String): List<Product> = try {
        if (text.isBlank()) emptyList() else roomJson.decodeFromString(text)
    } catch (_: Throwable) { emptyList() }

    fun scanQuality(room: Room): String = room.scanQuality().name

    fun initialPlacement(room: Room, width: Double, depth: Double): Pose = fitcheck.initialPlacement(room, Dimensions(width, depth, 1.0))
}
