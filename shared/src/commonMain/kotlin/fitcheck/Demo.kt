package fitcheck

fun demoRoom(): Room {
    val polygon=listOf(Point(0.0,0.0),Point(5.0,0.0),Point(5.0,3.0),Point(3.5,3.0),Point(3.5,4.5),Point(0.0,4.5))
    val walls=polygon.indices.map { i -> val a=polygon[i]; val b=polygon[(i+1)%polygon.size]
        RoomElement("wall-$i","wall",Dimensions(kotlin.math.hypot(b.x-a.x,b.z-a.z),.0,2.7),Pose((a.x+b.x)/2,(a.z+b.z)/2,kotlin.math.atan2(b.z-a.z,b.x-a.x))) }
    return Room(name="Saved demo · L-shaped study",capturedAt="2026-09-20T00:00:00Z",walls=walls,
        objects=listOf(RoomElement("desk","desk",Dimensions(1.4,.65,.75),Pose(1.3,.5)),RoomElement("sofa","sofa",Dimensions(1.8,.85,.8),Pose(.6,2.8,1.5707963267948966))),
        boundary=polygon,boundaryComplete=true,savedDemo=true)
}
fun demoProducts(): List<Product> = listOf(
    Product("fixture-a","Amazon UAE","Fixture A · Black task chair","https://www.amazon.ae/",price=349.0,currency="AED",retrievedAt="2026-09-20T00:00:00Z",variant="DEMO-A / black",
        dimensions=SizeEvidence(Dimensions(.62,.64,1.12),"SAVED SYNTHETIC FIXTURE: assembled width 62 cm; depth 64 cm; height 112 cm. Black. Fixed armrests. AED 349."),
        features=listOf(Feature("black",EvidenceStatus.SUPPORTED,"Fixture colour: black"),Feature("armrests",EvidenceStatus.SUPPORTED,"Fixture: fixed armrests")),source="Synthetic demonstration listing; not a real retailer offer.",savedDemo=true),
    Product("fixture-b","Noon UAE","Fixture B · Compact desk chair","https://www.noon.com/uae-en/",price=289.0,currency="AED",retrievedAt="2026-09-20T00:00:00Z",variant="DEMO-B / black",
        dimensions=SizeEvidence(Dimensions(.56,.58,1.02),"SAVED SYNTHETIC FIXTURE: assembled width 56 cm; depth 58 cm; height 102 cm. Black; no armrests. AED 289."),
        features=listOf(Feature("black",EvidenceStatus.SUPPORTED,"Fixture: black"),Feature("armrests",EvidenceStatus.UNSUPPORTED,"Fixture: no armrests")),source="Synthetic demonstration listing; not a real retailer offer.",savedDemo=true),
    Product("fixture-c","Temu","Fixture C · Chair with unknown assembled size","https://www.temu.com/",price=219.0,currency="AED",retrievedAt="2026-09-20T00:00:00Z",
        issues=listOf("Only package dimensions available; manual assembled dimensions required"),source="SAVED SYNTHETIC FIXTURE: package dimensions 70 × 40 × 60 cm. AED 219. Assembly required.",savedDemo=true)
)
