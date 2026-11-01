package fitcheck
import kotlin.test.*
import kotlin.math.PI
import kotlin.math.atan2
import kotlin.math.hypot
import kotlinx.serialization.encodeToString

class CoreTest {
    @Test fun convertsUnitsAndRejectsMalformed() {
        assertEquals(.62,metres(62.0,"cm"),1e-9)
        assertEquals(.0254,metres(1.0,"in"),1e-9)
        assertEquals(.62,metres(620.0,"mm"),1e-9)
        assertFails {metres(-1.0,"cm")};assertFails {metres(Double.NaN,"cm")};assertFails {metres(2.0,"feet")}
        assertFalse(Dimensions(.5,0.0,1.0).valid())
    }
    @Test fun rotatedRectangleUsesFullFootprint() {
        val p=footprint(Dimensions(2.0,1.0,1.0),Pose(0.0,0.0,PI/2))
        assertEquals(.5,p.maxOf {it.x},1e-9);assertEquals(1.0,p.maxOf {it.z},1e-9)
        val r=demoRoom()
        assertFalse(checkPlacement(r,Dimensions(1.0,1.0,1.0),Pose(4.8,1.5)).fits)
        assertTrue(checkPlacement(r,Dimensions(.5,.5,1.0),Pose(2.5,2.0,PI/4)).fits)
    }
    @Test fun overlapChecksRotatedEdgesAndTouching() {
        val a=footprint(Dimensions(2.0,.3,1.0),Pose(0.0,0.0,PI/4))
        assertTrue(overlaps(a,footprint(Dimensions(2.0,.3,1.0),Pose(0.0,0.0,-PI/4))))
        assertFalse(overlaps(a,footprint(Dimensions(.3,.3,1.0),Pose(3.0,3.0))))
        val square=Dimensions(1.0,1.0,1.0)
        assertTrue(overlaps(footprint(square,Pose()),footprint(square,Pose(1.0,0.0))))
    }
    @Test fun concaveBoundaryCannotBeBridgedByCorners() {
        val u=listOf(Point(0.0,0.0),Point(4.0,0.0),Point(4.0,4.0),Point(3.0,4.0),Point(3.0,1.0),Point(1.0,1.0),Point(1.0,4.0),Point(0.0,4.0))
        val box=footprint(Dimensions(3.5,.5,1.0),Pose(2.0,3.0))
        assertTrue(box.all {inside(it,u)})
        assertFalse(contained(box,u))
    }
    @Test fun missingBoundaryNeverConfirmsFit() {
        val r=demoRoom().copy(boundaryComplete=false,boundary=emptyList(),walls=emptyList())
        val check=checkPlacement(r,Dimensions(.5,.5,1.0),Pose(2.5,2.0))
        assertFalse(check.fits);assertFalse(check.complete);assertContains(check.explanation(),"incomplete")
    }
    @Test fun roundTripAndWallReconstruction() {
        val r=demoRoom();assertEquals(r,decodeRoom(roomJson.encodeToString(r)))
        val reconstructed=decodeRoom(roomJson.encodeToString(r.copy(boundary=emptyList(),boundaryComplete=false)))
        assertTrue(reconstructed.boundaryComplete);assertEquals(6,reconstructed.boundary.size)
        assertFalse(decodeRoom(roomJson.encodeToString(r.copy(walls=r.walls.dropLast(1),boundary=emptyList(),boundaryComplete=false))).boundaryComplete)
        assertFails {decodeRoom(roomJson.encodeToString(r.copy(schemaVersion=2)))}
        assertFails {decodeRoom(roomJson.encodeToString(r.copy(units="cm")))}
    }
    @Test fun roomPlanTransformPreservesYaw() {
        val matrix=listOf(0.0,0.0,1.0,0.0, 0.0,1.0,0.0,0.0, -1.0,0.0,0.0,0.0, 2.0,0.0,3.0,1.0)
        val objectElement=RoomElement("a","desk",Dimensions(1.0,.5,.8),Pose(2.0,3.0,PI/2),matrix)
        val r=demoRoom().copy(objects=listOf(objectElement))
        assertEquals(PI/2,decodeRoom(roomJson.encodeToString(r)).objects.single().pose.yaw)
        assertFails {decodeRoom(roomJson.encodeToString(r.copy(objects=listOf(objectElement.copy(pose=Pose())))))}
    }
    @Test fun boundaryInferenceWithholdsFitAcrossGapsAndAmbiguousJoins() {
        val r = demoRoom()
        // A ten-centimetre capture gap used to be silently bridged by a 15 cm tolerance.
        val wall = r.walls.first()
        val gapped = r.walls.toMutableList().apply {
            this[0] = wall.copy(dimensions = wall.dimensions.copy(width = wall.dimensions.width - .1),
                pose = wall.pose.copy(x = wall.pose.x + .05))
        }
        val decoded = decodeRoom(roomJson.encodeToString(r.copy(walls = gapped, boundary = emptyList(), boundaryComplete = false)))
        assertFalse(decoded.boundaryComplete)
        assertFalse(checkPlacement(decoded, Dimensions(.5, .5, 1.0), Pose(2.5, 2.0)).fits)

        val corners = listOf(Point(0.0, 0.0), Point(4.0, 0.0), Point(4.0, 4.0), Point(0.0, 4.0), Point(0.0, .02))
        val ambiguous = corners.indices.map { i ->
            val a = corners[i]; val b = corners[(i + 1) % corners.size]
            RoomElement("w$i", "wall", Dimensions(hypot(b.x - a.x, b.z - a.z), 0.0, 2.7),
                Pose((a.x + b.x) / 2, (a.z + b.z) / 2, atan2(b.z - a.z, b.x - a.x)))
        }
        assertTrue(inferBoundary(ambiguous).isEmpty())
        assertTrue(inferBoundary(r.walls.reversed()).isNotEmpty())
    }
    @Test fun importRejectsGeometryThatWouldBeSkippedOrExhaustValidation() {
        val r = demoRoom()
        val obj = r.objects.first()
        assertFails { decodeRoom(roomJson.encodeToString(r.copy(objects = listOf(obj.copy(dimensions = Dimensions(101.0, 1.0, 1.0)))))) }
        assertFails { decodeRoom(roomJson.encodeToString(r.copy(objects = listOf(obj.copy(dimensions = Dimensions(1.0, 0.0, 1.0)))))) }
        assertFails { decodeRoom(roomJson.encodeToString(r.copy(boundary = List(2001) { Point(it.toDouble(), 0.0) }, boundaryComplete = false))) }
        assertFails { decodeRoom(roomJson.encodeToString(r.copy(boundary = listOf(Point(1001.0, 0.0)), boundaryComplete = false))) }
    }
    @Test fun initialPlacementFindsSpaceAwayFromAConcaveRoomsCentre() {
        val u = listOf(Point(0.0, 0.0), Point(4.0, 0.0), Point(4.0, 4.0), Point(3.0, 4.0),
            Point(3.0, 1.0), Point(1.0, 1.0), Point(1.0, 4.0), Point(0.0, 4.0))
        val room = demoRoom().copy(walls = emptyList(), objects = emptyList(), boundary = u)
        val chair = Dimensions(.5, .5, 1.0)
        assertFalse(checkPlacement(room, chair, Pose(2.0, 2.0)).fits)
        assertTrue(checkPlacement(room, chair, initialPlacement(room, chair)).fits)
    }
    @Test fun missingPriceIsNotAFreeChair() {
        val p=demoProducts().first();val r=Preferences(budget=400.0)
        assertEquals(EvidenceStatus.SUPPORTED,budgetStatus(p,r))
        assertEquals(EvidenceStatus.UNSUPPORTED,budgetStatus(p.copy(price=450.0),r))
        assertEquals(EvidenceStatus.UNKNOWN,budgetStatus(p.copy(price=null),r))
        assertEquals(EvidenceStatus.UNKNOWN,budgetStatus(p.copy(currency="USD"),r))
    }
    @Test fun packagingAndMissingDimensionsCannotPreview() {
        val p=demoProducts().first()
        assertNotNull(p.previewSize());assertNull(p.copy(dimensions=null).previewSize())
        assertNull(p.copy(dimensions=p.dimensions!!.copy(kind="package")).previewSize())
        assertNull(p.copy(dimensions=p.dimensions!!.copy(source="")).previewSize())
        assertNull(demoProducts().last().previewSize())
    }
    @Test fun manuallyEnteredListingsKeepTheirProvenanceThroughSerialization() {
        val manual = Product(
            id = "manual-chair", retailer = "Amazon UAE", title = "My chair",
            url = "https://www.amazon.ae/dp/B000000001", retrievedAt = "2026-11-01T12:00:00Z",
            dimensions = SizeEvidence(Dimensions(.6, .6, 1.0), "Measured by user", origin = "user-provided"),
            source = "User-entered listing details; verify the retailer page.",
            provenance = ProductProvenance.USER_ENTERED
        )
        val bridge = RoomBridge()
        val saved = bridge.encodeProducts(listOf(manual))
        assertContains(saved, "\"provenance\": \"USER_ENTERED\"")
        val loaded = bridge.decodeProducts(saved).single()
        assertEquals(manual, loaded)
        assertEquals(ProductProvenance.USER_ENTERED, loaded.provenance)
        assertFalse(loaded.savedDemo)
        assertEquals("user-provided", loaded.dimensions!!.origin)
        assertNotEquals(ProductProvenance.LIVE, loaded.provenance)
        assertNotEquals(ProductProvenance.SAVED_LIVE, loaded.provenance)
        assertNotEquals(ProductProvenance.FIXTURE, loaded.provenance)
        // Existing persisted enum names remain wire-compatible.
        for (provenance in listOf(ProductProvenance.FIXTURE, ProductProvenance.LIVE, ProductProvenance.SAVED_LIVE)) {
            val old = manual.copy(provenance = provenance, savedDemo = provenance == ProductProvenance.FIXTURE)
            assertEquals(provenance, bridge.decodeProducts(bridge.encodeProducts(listOf(old))).single().provenance)
        }
    }
}
