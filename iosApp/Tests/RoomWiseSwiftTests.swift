import XCTest
import Foundation
import SwiftUI
import UIKit
import SceneKit
import FitCheckShared
@testable import FitCheck

private final class StubHTTPTransport: HTTPTransport {
    struct StubResponse {
        let data: Data
        let statusCode: Int
    }

    private(set) var requests: [URLRequest] = []
    private var responses: [StubResponse]

    init(responses: [StubResponse]) {
        self.responses = responses
    }

    func send(request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requests.append(request)
        guard !responses.isEmpty else { throw URLError(.badServerResponse) }
        let response = responses.removeFirst()
        let http = HTTPURLResponse(
            url: request.url!,
            statusCode: response.statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
        return (response.data, http)
    }
}

final class RoomWiseSwiftTests: XCTestCase {

    // MARK: - 1. Case-Insensitive Chair Filtering
    func testCaseInsensitiveChairMatching() {
        // Lowercase
        XCTAssertTrue(RetailerService.isChairMatch(title: "ergonomic mesh chair with lumbar support", content: ""))
        // Title Case
        XCTAssertTrue(RetailerService.isChairMatch(title: "Ergonomic Office Chair", content: ""))
        // UPPERCASE
        XCTAssertTrue(RetailerService.isChairMatch(title: "MODERN EXECUTIVE CHAIR HIGH BACK", content: ""))
        // Arabic
        XCTAssertTrue(RetailerService.isChairMatch(title: "كرسي مكتب مريح", content: ""))
        // In content only
        XCTAssertTrue(RetailerService.isChairMatch(title: "Steelcase Series 2", content: "High performance desk chair for home office"))
        // Unrelated non-chair result rejected
        XCTAssertFalse(RetailerService.isChairMatch(title: "Modern Wooden Dining Table", content: "Solid oak table seats 6"))
        XCTAssertFalse(RetailerService.isChairMatch(title: "Bookshelf with 5 Shelves", content: "Storage unit for living room"))
        // Search-result accessories must not consume the complete-chair candidate slots.
        XCTAssertFalse(RetailerService.isChairMatch(title: "Office Chair Armrest Replacement Pads", content: "Universal replacement part"))
        XCTAssertFalse(RetailerService.isChairMatch(title: "Stretchable Office Chair Covers", content: "Washable slipcover"))
    }

    // MARK: - 2. Retailer Domain Constraints & URL Retention
    func testRetailerDomainConstraintsAndUrlRetention() {
        let validAmazonUrl = "https://www.amazon.ae/dp/B000000001"
        let validNoonUrl = "https://www.noon.com/uae-en/chair/N00001/p/"
        let validTemuUrl = "https://www.temu.com/chair-g-601234567890.html"

        XCTAssertTrue(Retailer.amazon.accepts(url: validAmazonUrl), "Valid Amazon product URL accepted")
        XCTAssertFalse(Retailer.amazon.accepts(url: "https://www.amazon.ae/s?k=chairs"), "Amazon search URL rejected")
        XCTAssertFalse(Retailer.amazon.accepts(url: "https://amazon.ae.phishing.com/dp/B000000001"), "Phishing URL rejected")
        XCTAssertFalse(Retailer.amazon.accepts(url: "http://www.amazon.ae/dp/B000000001"), "Insecure HTTP rejected")

        XCTAssertTrue(Retailer.noon.accepts(url: validNoonUrl), "Valid Noon product URL accepted")
        XCTAssertFalse(Retailer.noon.accepts(url: "https://www.noon.com/uae-en/"), "Noon category URL rejected")

        XCTAssertTrue(Retailer.temu.accepts(url: validTemuUrl), "Valid Temu product URL accepted")
        XCTAssertFalse(Retailer.temu.accepts(url: "https://www.temu.com/"), "Temu home URL rejected")

        // Extraction retains exact product URL
        let listing = Listing(id: "amz-1", retailer: Retailer.amazon, title: "Executive Chair", url: validAmazonUrl, snippet: "", imageUrl: nil)
        let prefs = Preferences(category: "chair", budget: nil, currency: "AED", colour: nil, requiredFeatures: [], preferredFeatures: [], maxWidth: nil, maxDepth: nil, unknowns: [])
        let extracted = ProductExtractionKt.extractProduct(listing: listing, text: "Price: AED 299\nWidth: 60 cm Depth: 60 cm Height: 100 cm", request: prefs, retrievedAt: "2026-09-20T00:00:00Z")

        XCTAssertEqual(extracted.url, validAmazonUrl, "Product card must retain the exact listing URL")
    }

    // MARK: - 3. Sample Store Links vs Live Product Links
    func testSampleHomepageBehavior() {
        let demoProducts = DemoKt.demoProducts()
        for fixture in demoProducts {
            XCTAssertEqual(fixture.provenance, ProductProvenance.fixture, "Demo product must have FIXTURE provenance")
            let retailer = [Retailer.amazon, Retailer.noon, Retailer.temu].first(where: { $0.label == fixture.retailer })
            XCTAssertNotNil(retailer)
            // Fixture URLs point to homepages, which must NOT be accepted as product URLs
            XCTAssertFalse(retailer!.accepts(url: fixture.url), "Homepage URL \(fixture.url) must not be accepted as a product URL")
        }
    }

    // MARK: - 4. Persisted Fixture and Live Provenance
    func testPersistedFixtureAndLiveProvenance() {
        RoomPersistence.clearSession()
        defer { RoomPersistence.clearSession() }

        let fixture = Product(
            id: "fix-1", retailer: "Amazon UAE", title: "Sample Chair", url: "https://www.amazon.ae/",
            imageUrl: nil, price: KotlinDouble(value: 299.0), currency: "AED", retrievedAt: "2026-09-20T00:00:00Z",
            variant: nil, seller: nil, dimensions: nil, features: [], delivery: nil, availability: nil,
            issues: [], source: "sample", savedDemo: true, provenance: ProductProvenance.fixture
        )
        let live = Product(
            id: "live-1", retailer: "Amazon UAE", title: "Real Chair", url: "https://www.amazon.ae/dp/B000000001",
            imageUrl: nil, price: KotlinDouble(value: 399.0), currency: "AED", retrievedAt: "2026-09-20T00:00:00Z",
            variant: nil, seller: nil, dimensions: nil, features: [], delivery: nil, availability: nil,
            issues: [], source: "tavily", savedDemo: false, provenance: ProductProvenance.live
        )

        RoomPersistence.saveSession(
            room: DemoKt.demoRoom(),
            query: "Office chair",
            products: [fixture, live],
            selectedProductId: live.id,
            chairPose: Pose(x: 2.0, z: 2.0, yaw: 0.0),
            retailerStatuses: ["Amazon UAE": "1 retrieved"],
            sampleMode: false
        )

        let loaded = RoomPersistence.loadSession()
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.products.count, 2)

        let loadedFixture = loaded?.products.first(where: { $0.id == "fix-1" })
        let loadedLive = loaded?.products.first(where: { $0.id == "live-1" })

        XCTAssertEqual(loadedFixture?.provenance, ProductProvenance.fixture, "Fixture must retain FIXTURE provenance")
        XCTAssertEqual(loadedLive?.provenance, ProductProvenance.savedLive, "Live product must be restored as SAVED_LIVE, never fixture")
    }

    // MARK: - 5. Zero-Result Live Search Surviving Relaunch
    func testZeroResultLiveSearchSurvivesRelaunchWithoutDemoResurrection() {
        RoomPersistence.clearSession()
        defer { RoomPersistence.clearSession() }

        // Save a session where live search returned 0 products
        RoomPersistence.saveSession(
            room: DemoKt.demoRoom(),
            query: "Unicorn chair impossible query",
            products: [],
            selectedProductId: nil,
            chairPose: Pose(x: 2.0, z: 2.0, yaw: 0.0),
            retailerStatuses: ["Amazon UAE": "No verified results"],
            sampleMode: false
        )

        let loaded = RoomPersistence.loadSession()
        XCTAssertNotNil(loaded, "Saved session exists")
        XCTAssertEqual(loaded?.products.count, 0, "Products list must remain empty after relaunch")
        XCTAssertFalse(loaded?.sampleMode ?? true, "Sample mode must remain false")
    }

    // MARK: - 6. Missing Credentials State
    func testMissingCredentialsState() {
        let creds = SessionCredentials(store: InMemoryCredentialStore())
        creds.apiKey = ""
        creds.tavilyKey = ""

        XCTAssertNotNil(creds.validationError)
        XCTAssertTrue(creds.validationError!.contains("Tavily search key"))

        creds.apiKey = "fake-openai-key"
        XCTAssertNotNil(creds.validationError)
        XCTAssertTrue(creds.validationError!.contains("Tavily search key"))

        creds.tavilyKey = "fake-tavily-key"
        XCTAssertNil(creds.validationError)

        creds.apiKey = ""
        XCTAssertNil(creds.validationError, "Tavily-only retrieval must allow the deterministic parser fallback")

        creds.provider = "anthropic"
        XCTAssertNotNil(creds.validationError)
        XCTAssertTrue(creds.validationError!.contains("Only OpenAI is supported"))
    }

    // MARK: - 7. Stale Request Callback Isolation
    func testStaleRequestCallbackIsolation() {
        let requestA = UUID()
        let requestB = UUID()
        var activeRequestId = requestA

        var receivedUpdates = [UUID: [String]]()
        let onStoreUpdate: (UUID, String, [String]) -> Void = { reqId, store, prods in
            guard reqId == activeRequestId else { return }
            receivedUpdates[reqId] = prods
        }

        // Request A emits update
        onStoreUpdate(requestA, "Amazon UAE", ["Chair A1"])
        XCTAssertEqual(receivedUpdates[requestA]?.count, 1)

        // Request B supersedes Request A
        activeRequestId = requestB
        onStoreUpdate(requestB, "Amazon UAE", ["Chair B1", "Chair B2"])
        XCTAssertEqual(receivedUpdates[requestB]?.count, 2)

        // Late update from Request A arrives
        onStoreUpdate(requestA, "Amazon UAE", ["Chair A2 (late)"])
        XCTAssertEqual(receivedUpdates[requestB]?.count, 2, "Active request remains Request B")
        XCTAssertEqual(receivedUpdates[requestA]?.count, 1, "Late update was discarded")
    }

    // MARK: - 8. Cancellation Using Production Code
    func testCancellationUsingProductionCode() async {
        let controller = RoomCaptureController()
        XCTAssertEqual(controller.phase, CapturePhase.idle)

        let session = ScanSession(controller: controller)
        controller.setActiveSessionForTesting(session)
        XCTAssertEqual(controller.activeSessionId, session.id)

        controller.cancelScan()
        XCTAssertEqual(controller.phase, CapturePhase.idle)
        XCTAssertNil(controller.activeSessionId)
        XCTAssertTrue(session.isCancelled)

        // Late callback from cancelled session must be rejected
        XCTAssertFalse(session.shouldAcceptCallback, "Cancelled session must not accept callbacks")
    }

    // MARK: - 9. Scan Quality: 2-Wall Partial vs Closed Room
    func testScanQualityClassificationAndFitCheck() {
        // Physical scan from Aadil's phone: 2 walls, no boundary points, boundaryComplete = false
        let twoWallJson = """
        {
            "schemaVersion": 1,
            "units": "m",
            "coordinates": "right-handed:Y-up:floor-XZ:yaw-X-toward-Z",
            "name": "Physical Scan",
            "capturedAt": "2026-09-20T12:59:17Z",
            "walls": [
                {"id": "w1", "kind": "wall", "pose": {"x": 0.0, "z": 0.0, "yaw": 0.0}, "dimensions": {"width": 3.0, "depth": 0.1, "height": 2.5}},
                {"id": "w2", "kind": "wall", "pose": {"x": 1.5, "z": 2.0, "yaw": 1.5708}, "dimensions": {"width": 4.0, "depth": 0.1, "height": 2.5}}
            ],
            "openings": [],
            "objects": [],
            "boundary": [],
            "boundaryComplete": false,
            "savedDemo": false
        }
        """

        let partialRoom = RoomPersistence.safeDecodeRoom(json: twoWallJson)
        XCTAssertNotNil(partialRoom)
        let quality = partialRoom!.scanQuality()
        XCTAssertEqual(quality, ScanQuality.partial, "Two-wall scan must be classified as PARTIAL")

        let chairDims = Dimensions(width: 0.62, depth: 0.64, height: 1.12)
        let pose = Pose(x: 1.0, z: 1.0, yaw: 0.0)
        let placement = GeometryKt.checkPlacement(room: partialRoom!, d: chairDims, p: pose)
        XCTAssertFalse(placement.fits, "Two-wall room must never receive a positive fit result")
        XCTAssertTrue(placement.boundary.contains("incomplete") || placement.boundary.contains("partial"), "Boundary must indicate incomplete/partial")

        // Closed demo room
        let closedRoom = DemoKt.demoRoom()
        let closedQuality = closedRoom.scanQuality()
        XCTAssertEqual(closedQuality, ScanQuality.complete, "Closed room must be classified as COMPLETE")
        let fitResult = GeometryKt.checkPlacement(room: closedRoom, d: chairDims, p: Pose(x: 2.5, z: 2.0, yaw: 0.0))
        XCTAssertTrue(fitResult.fits, "Closed room can produce a positive fit result")
    }

    // MARK: - 10. New Room Recenter Behavior
    func testNewRoomRecenterBehavior() {
        let room = DemoKt.demoRoom()
        let chairDims = Dimensions(width: 0.62, depth: 0.64, height: 1.12)

        // Prior pose far outside useful scan region (e.g. phone's stale pose at z = 6.74)
        let stalePose = Pose(x: 2.1833, z: 6.7361, yaw: 6.28)
        let priorCheck = GeometryKt.checkPlacement(room: room, d: chairDims, p: stalePose)
        XCTAssertFalse(priorCheck.fits, "Stale pose must be outside room")

        // Recenter
        let recentered = GeometryKt.initialPlacement(room: room, d: chairDims)
        let recenterCheck = GeometryKt.checkPlacement(room: room, d: chairDims, p: recentered)
        XCTAssertTrue(recenterCheck.fits, "Recentered pose must fit inside the room boundary")
    }

    // MARK: - 11. Corrupt Persisted Data Recovery
    func testCorruptPersistedDataRecovery() {
        XCTAssertNil(RoomPersistence.safeDecodeRoom(json: ""))
        XCTAssertNil(RoomPersistence.safeDecodeRoom(json: "   "))
        XCTAssertNil(RoomPersistence.safeDecodeRoom(json: "{ invalid json !!!"))
        XCTAssertNil(RoomPersistence.safeDecodeRoom(json: "{\"schemaVersion\": 99}"))
    }

    // MARK: - 12. CredentialStore: Load, Update, Clear
    func testCredentialStoreOperations() throws {
        let store = InMemoryCredentialStore()

        // Initially empty
        XCTAssertNil(store.loadOpenAIKey())
        XCTAssertNil(store.loadTavilyKey())

        // Save keys
        try store.saveOpenAIKey("fake-openai-secret-12345")
        try store.saveTavilyKey("fake-tavily-secret-67890")

        XCTAssertEqual(store.loadOpenAIKey(), "fake-openai-secret-12345")
        XCTAssertEqual(store.loadTavilyKey(), "fake-tavily-secret-67890")

        // Load into session
        let sessionCreds = SessionCredentials(store: store)
        XCTAssertTrue(sessionCreds.hasOpenAIKey)
        XCTAssertTrue(sessionCreds.hasTavilyKey)
        XCTAssertNil(sessionCreds.validationError)
        XCTAssertEqual(sessionCreds.openAISource, CredentialSource.keychain)
        XCTAssertEqual(sessionCreds.tavilySource, CredentialSource.keychain)

        // Update key
        try store.saveOpenAIKey("fake-openai-updated-99999")
        XCTAssertEqual(store.loadOpenAIKey(), "fake-openai-updated-99999")

        // Clear keys
        try sessionCreds.clear()
        XCTAssertNil(store.loadOpenAIKey())
        XCTAssertNil(store.loadTavilyKey())
        XCTAssertFalse(sessionCreds.hasOpenAIKey)
        XCTAssertFalse(sessionCreds.hasTavilyKey)
    }

    func testRuntimeCredentialsUseUserStoreAndFreeKeysStaySeparate() throws {
        let empty = SessionCredentials(store: InMemoryCredentialStore())
        XCTAssertFalse(empty.hasGroqKey)
        XCTAssertFalse(empty.hasTavilyKey)
        XCTAssertFalse(empty.hasOpenAIKey, "Repository Debug secrets must never become active app credentials")

        let store = InMemoryCredentialStore(initialOpenAIKey: "legacy-openai", initialTavilyKey: "old-tavily", initialGroqKey: "old-groq")
        let session = SessionCredentials(store: store)
        XCTAssertEqual(session.groqKey, "old-groq")
        XCTAssertEqual(session.groqModel, "openai/gpt-oss-20b")
        session.groqKey = "new-groq"
        session.tavilyKey = "new-tavily"
        try session.saveFreeKeys()
        XCTAssertEqual(store.loadGroqKey(), "new-groq")
        XCTAssertEqual(store.loadTavilyKey(), "new-tavily")
        XCTAssertEqual(store.loadOpenAIKey(), "legacy-openai", "Free settings must not write legacy provider credentials")

        try session.clearFreeKeys()
        XCTAssertNil(store.loadGroqKey())
        XCTAssertNil(store.loadTavilyKey())
        XCTAssertEqual(store.loadOpenAIKey(), "legacy-openai")
        XCTAssertFalse(session.hasGroqKey)
        XCTAssertFalse(session.hasTavilyKey)
    }

    // MARK: - 14. Secret Leakage Regression Test
    func testSecretLeakageRegression() throws {
        let fakeOpenAI = "fake-secret-openai-leak-test-abc123"
        let fakeTavily = "fake-secret-tavily-leak-test-xyz789"
        let fakeGroq = "fake-secret-groq-leak-test-pqr456"

        let store = InMemoryCredentialStore()
        try store.saveOpenAIKey(fakeOpenAI)
        try store.saveTavilyKey(fakeTavily)
        try store.saveGroqKey(fakeGroq)

        let creds = SessionCredentials(store: store)
        creds.apiKey = fakeOpenAI
        creds.tavilyKey = fakeTavily
        creds.groqKey = fakeGroq
        XCTAssertEqual(creds.apiKey, fakeOpenAI)
        XCTAssertEqual(creds.tavilyKey, fakeTavily)

        // Persist session
        let room = DemoKt.demoRoom()
        let products = DemoKt.demoProducts()
        RoomPersistence.saveSession(
            room: room,
            query: "Black chair",
            products: products,
            selectedProductId: products.first?.id,
            chairPose: Pose(x: 2.0, z: 2.0, yaw: 0.0),
            retailerStatuses: ["Amazon UAE": "1 retrieved"],
            sampleMode: true
        )

        // Inspect the actual storage implementation instead of a nonexistent
        // historical session file, which would make this assertion vacuous.
        let roomwiseValues = UserDefaults.standard.dictionaryRepresentation().filter { $0.key.hasPrefix("roomwise_") }
        let storedText = String(describing: roomwiseValues)
        for secret in [fakeOpenAI, fakeTavily, fakeGroq] {
            XCTAssertFalse(storedText.contains(secret), "Saved room/search preferences must never contain provider keys")
        }

        // Export room
        let exportUrl = RoomPersistence.createExportFile(for: room)
        if let url = exportUrl, let content = try? String(contentsOf: url) {
            XCTAssertFalse(content.contains(fakeOpenAI), "Exported room must NEVER contain OpenAI key")
            XCTAssertFalse(content.contains(fakeTavily), "Exported room must NEVER contain Tavily key")
            XCTAssertFalse(content.contains(fakeGroq), "Exported room must NEVER contain Groq key")
        }

        // Clean up
        try store.clear()
        RoomPersistence.clearSession()
    }

    // MARK: - 15. Retail Search Anchoring & Candidate Filtering
    func testRetailSearchAnchorsDomainAndSkipsAccessoryResults() async throws {
        let payload: [String: Any] = [
            "results": [
                [
                    "title": "UNDER Definition & Meaning",
                    "url": "https://www.dictionary.com/browse/under",
                    "content": "Dictionary entry"
                ],
                [
                    "title": "Office Chair Armrest Replacement Pads",
                    "url": "https://www.amazon.ae/replacement-pads/dp/B000000001",
                    "content": "Replacement part for a chair"
                ],
                [
                    "title": "Ergonomic Black Office Chair",
                    "url": "https://www.amazon.ae/ergonomic-chair/dp/B000000002",
                    "content": "Complete mesh desk chair"
                ],
                [
                    "title": "Executive Desk Chair",
                    "url": "https://www.amazon.ae/executive-chair/dp/B000000003",
                    "content": "Complete office chair"
                ]
            ]
        ]
        let data = try JSONSerialization.data(withJSONObject: payload)
        let transport = StubHTTPTransport(responses: [.init(data: data, statusCode: 200)])
        let service = RetailerService(transport: transport)
        let prefs = Preferences(
            category: "chair", budget: KotlinDouble(value: 1_000), currency: "AED", colour: "black",
            requiredFeatures: ["armrests"], preferredFeatures: [], maxWidth: nil, maxDepth: nil, unknowns: []
        )

        let listings = try await service.search(store: Retailer.amazon, request: prefs, tavilyKey: "test-key")

        XCTAssertEqual(listings.map(\.title), ["Ergonomic Black Office Chair", "Executive Desk Chair"])
        let request = try XCTUnwrap(transport.requests.first)
        let bodyData = try XCTUnwrap(request.httpBody)
        let body = try XCTUnwrap(try JSONSerialization.jsonObject(with: bodyData) as? [String: Any])
        let query = try XCTUnwrap(body["query"] as? String)
        XCTAssertTrue(query.contains("site:amazon.ae"))
        XCTAssertTrue(query.contains("AED 1000.0 maximum"))
        XCTAssertEqual(body["max_results"] as? Int, 10)
        XCTAssertEqual(body["search_depth"] as? String, "basic")
        XCTAssertEqual(body["auto_parameters"] as? Bool, false)
        XCTAssertNil(body["country"], "A country filter must not suppress otherwise valid retailer pages")
    }

    // MARK: - 16. Honest Search-Evidence Fallback
    func testEmptyPageExtractionRetainsValidatedSearchEvidence() async throws {
        let emptyExtraction = try JSONSerialization.data(withJSONObject: ["results": []])
        let transport = StubHTTPTransport(responses: [.init(data: emptyExtraction, statusCode: 200)])
        let service = RetailerService(transport: transport)
        let prefs = Preferences(
            category: "chair", budget: nil, currency: "AED", colour: "black",
            requiredFeatures: [], preferredFeatures: [], maxWidth: nil, maxDepth: nil, unknowns: []
        )
        let listing = Listing(
            id: "temu-live-1",
            retailer: Retailer.temu,
            title: "Black Ergonomic Office Chair",
            url: "https://www.temu.com/ae/black-ergonomic-office-chair-g-601099572358825.html",
            snippet: "Black ergonomic office chair with a mesh back.",
            imageUrl: nil
        )

        let product = try await service.extract(listing: listing, request: prefs, tavilyKey: "test-key")

        XCTAssertNotNil(product)
        XCTAssertEqual(product?.url, listing.url)
        XCTAssertEqual(product?.provenance, ProductProvenance.live)
        XCTAssertNil(product?.price, "A search snippet without a price must not create one")
        XCTAssertNil(product?.previewSize(), "A search snippet without dimensions must not create them")
        XCTAssertTrue(product?.source.contains("Tavily search result snippet") == true)
        XCTAssertTrue(product?.issues.contains(where: { $0.contains("search-result evidence only") }) == true)
    }

    func testExtractionNeverAttachesAnotherPagesFactsToListing() async throws {
        let payload: [String: Any] = ["results": [[
            "url": "https://www.amazon.ae/dp/B000000099",
            "raw_content": "AED 999\nProduct dimensions: Width: 90 cm Depth: 90 cm Height: 90 cm"
        ]]]
        let transport = StubHTTPTransport(responses: [.init(data: try JSONSerialization.data(withJSONObject: payload), statusCode: 200)])
        let service = RetailerService(transport: transport)
        let listing = Listing(id: "chair", retailer: Retailer.amazon, title: "Office Chair", url: "https://www.amazon.ae/dp/B000000001", snippet: "Mesh office chair", imageUrl: nil)
        let prefs = ProductExtractionKt.parseFixtureRequest(text: "black chair")
        let product = try await service.extract(listing: listing, request: prefs, tavilyKey: "test-key")

        XCTAssertEqual(product?.url, listing.url)
        XCTAssertNil(product?.price, "Facts from a different result URL must be withheld")
        XCTAssertNil(product?.previewSize())
        XCTAssertTrue(product?.issues.contains(where: { $0.contains("search-result evidence only") }) == true)
    }

    func testAgentCompletesListingsWhenAIStopsAfterSearch() async throws {
        func response(_ object: [String: Any]) throws -> StubHTTPTransport.StubResponse {
            .init(data: try JSONSerialization.data(withJSONObject: object), statusCode: 200)
        }
        let productURL = "https://www.amazon.ae/dp/B000000001"
        let transport = StubHTTPTransport(responses: [
            try response(["choices": [["message": ["role": "assistant", "tool_calls": [
                ["id": "prefs", "type": "function", "function": ["name": "set_preferences", "arguments": "{\"category\":\"chair\",\"currency\":\"AED\"}"]],
                ["id": "search", "type": "function", "function": ["name": "search_retailer_listings", "arguments": "{\"store\":\"AMAZON\"}"]]
            ]]]]]),
            try response(["results": [["url": productURL, "title": "Mesh Office Chair", "content": "Mesh desk chair"]]]),
            try response(["choices": [["message": ["role": "assistant", "content": "Done"]]]]),
            try response(["results": [["url": productURL, "raw_content": "AED 299\nProduct dimensions: Width: 60 cm Depth: 60 cm Height: 100 cm"]]]),
            try response(["results": []]),
            try response(["results": []])
        ])
        let credentials = SessionCredentials(store: InMemoryCredentialStore())
        credentials.apiKey = "test-openai-key"
        credentials.tavilyKey = "test-tavily-key"
        var retrieved: [String: [Product]] = [:]

        _ = try await ShoppingAgent(transport: transport).run(
            requestId: UUID(), prompt: "Mesh office chair", room: DemoKt.demoRoom(), credentials: credentials,
            onStatus: { _, _ in },
            onStoreUpdate: { _, store, products, _ in retrieved[store] = products },
            onPreview: { _, _, _ in }
        )

        XCTAssertEqual(retrieved["Amazon UAE"]?.count, 1, "Stored candidates must be extracted even if the AI finishes early")
        XCTAssertEqual(retrieved["Amazon UAE"]?.first?.price?.doubleValue, 299)
        XCTAssertEqual(transport.requests.filter { $0.url?.path == "/search" }.count, 3, "Search each store at most once")
        XCTAssertEqual(transport.requests.filter { $0.url?.path == "/extract" }.count, 1)
    }

    func testTransportCancellationDoesNotReturnFallbackCard() async {
        final class CancelledTransport: HTTPTransport {
            func send(request: URLRequest) async throws -> (Data, HTTPURLResponse) { throw URLError(.cancelled) }
        }
        let service = RetailerService(transport: CancelledTransport())
        let listing = Listing(id: "cancelled", retailer: Retailer.amazon, title: "Office Chair", url: "https://www.amazon.ae/dp/B000000001", snippet: "Office chair", imageUrl: nil)
        do {
            _ = try await service.extract(listing: listing, request: ProductExtractionKt.parseFixtureRequest(text: "chair"), tavilyKey: "test-key")
            XCTFail("Cancelled transport must propagate cancellation")
        } catch is CancellationError {
            // Expected: a cancelled request cannot emit another result card.
        } catch {
            XCTFail("Expected CancellationError, got \(error)")
        }
    }

    func testDeleteSavedDataRemovesSessionAndTemporaryExport() throws {
        RoomPersistence.clearSavedData()
        defer { RoomPersistence.clearSavedData() }
        let room = DemoKt.demoRoom()
        RoomPersistence.saveSession(room: room, query: "Private search", products: [], selectedProductId: nil, chairPose: Pose(x: 2, z: 2, yaw: 0), retailerStatuses: [:], sampleMode: false)
        let exportURL = try XCTUnwrap(RoomPersistence.createExportFile(for: room))
        XCTAssertTrue(FileManager.default.fileExists(atPath: exportURL.path))

        RoomPersistence.clearSavedData()

        XCTAssertNil(RoomPersistence.loadSession())
        XCTAssertFalse(FileManager.default.fileExists(atPath: exportURL.path))
    }

    func testGroqFreeParserUsesOneStrictStructuredRequest() async throws {
        let content: [String: Any] = ["budget": 400, "currency": "aed", "colour": " black ", "requiredFeatures": ["Armrests", " armrests "], "maxWidthMetres": 0.7, "maxDepthMetres": NSNull()]
        let data = try groqResponse(content)
        let transport = StubHTTPTransport(responses: [.init(data: data, statusCode: 200)])
        let result = try await FreeShoppingParser.parse(prompt: "Black chair under AED 400 with armrests", groqKey: "test-groq-key", transport: transport)

        XCTAssertEqual(result.engineLabel, "Groq · GPT-OSS 20B")
        XCTAssertEqual(result.preferences.budget?.doubleValue, 400)
        XCTAssertEqual(result.preferences.currency, "AED")
        XCTAssertEqual(result.preferences.colour, "black")
        XCTAssertEqual(result.preferences.requiredFeatures, ["armrests"])
        XCTAssertEqual(result.preferences.maxWidth?.doubleValue, 0.7)
        XCTAssertEqual(transport.requests.count, 1)
        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.url?.host, "api.groq.com")
        XCTAssertEqual(request.url?.path, "/openai/v1/chat/completions")
        let body = try XCTUnwrap(try JSONSerialization.jsonObject(with: XCTUnwrap(request.httpBody)) as? [String: Any])
        XCTAssertEqual(body["model"] as? String, "openai/gpt-oss-20b")
        XCTAssertNil(body["tools"], "The free LLM only interprets the query; it cannot issue searches or access room data")
        let format = try XCTUnwrap(body["response_format"] as? [String: Any])
        let schema = try XCTUnwrap(format["json_schema"] as? [String: Any])
        XCTAssertEqual(schema["strict"] as? Bool, true)
        let definition = try XCTUnwrap(schema["schema"] as? [String: Any])
        XCTAssertEqual(definition["additionalProperties"] as? Bool, false)
        XCTAssertFalse(String(data: request.httpBody!, encoding: .utf8)!.contains("test-groq-key"))
    }

    func testMissingGroqKeyUsesOfflineParserWithoutNetwork() async throws {
        let transport = StubHTTPTransport(responses: [])
        let result = try await FreeShoppingParser.parse(prompt: "black chair under AED 400 with armrests", transport: transport)
        XCTAssertEqual(result.engineLabel, "Offline basic parser")
        XCTAssertEqual(result.preferences.budget?.doubleValue, 400)
        XCTAssertTrue(result.note.contains("No Groq key"))
        XCTAssertTrue(transport.requests.isEmpty)
    }

    func testGroqRateLimitFallsBackWithoutRetryOrPaidEscalation() async throws {
        let transport = StubHTTPTransport(responses: [.init(data: Data("{}".utf8), statusCode: 429)])
        let result = try await FreeShoppingParser.parse(prompt: "chair under AED 300", groqKey: "test-key", transport: transport)
        XCTAssertEqual(result.engineLabel, "Offline basic parser")
        XCTAssertEqual(result.preferences.budget?.doubleValue, 300)
        XCTAssertTrue(result.note.contains("quota or rate limit"))
        XCTAssertEqual(transport.requests.count, 1)
    }

    func testInvalidGroqRequirementsFallBackWithoutInventedLimits() async throws {
        let data = try groqResponse(["budget": 200, "currency": "AED", "colour": NSNull(), "requiredFeatures": [], "maxWidthMetres": 100, "maxDepthMetres": NSNull()])
        let transport = StubHTTPTransport(responses: [.init(data: data, statusCode: 200)])
        let result = try await FreeShoppingParser.parse(prompt: "chair under AED 300", groqKey: "test-key", transport: transport)
        XCTAssertEqual(result.engineLabel, "Offline basic parser")
        XCTAssertEqual(result.preferences.budget?.doubleValue, 300)
        XCTAssertNil(result.preferences.maxWidth)
    }

    func testFreeGroqParserPropagatesTransportCancellation() async {
        final class CancelledTransport: HTTPTransport {
            func send(request: URLRequest) async throws -> (Data, HTTPURLResponse) { throw URLError(.cancelled) }
        }
        do {
            _ = try await FreeShoppingParser.parse(prompt: "chair", groqKey: "test-key", transport: CancelledTransport())
            XCTFail("Cancellation must not be converted into a successful fallback search")
        } catch is CancellationError {
            // Expected.
        } catch {
            XCTFail("Expected CancellationError, got \(error)")
        }
    }

    private func groqResponse(_ content: [String: Any]) throws -> Data {
        let contentData = try JSONSerialization.data(withJSONObject: content)
        return try JSONSerialization.data(withJSONObject: ["choices": [["message": ["content": try XCTUnwrap(String(data: contentData, encoding: .utf8))]]]])
    }

    @MainActor
    func testFreeCatalogMakesAtMostThreeBasicRequestsWithoutExtraction() async throws {
        let suite = "RoomWise-FreeCatalog-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let allowance = FreeCatalogAllowance(defaults: defaults)
        let urls = ["https://www.amazon.ae/dp/B000000001", "https://www.noon.com/uae-en/chair/N00001/p/", "https://www.temu.com/chair-g-601234567890.html"]
        let responses = try urls.map { url in
            StubHTTPTransport.StubResponse(data: try JSONSerialization.data(withJSONObject: ["results": [["title": "Mesh Office Chair", "url": url, "content": "AED 299. Mesh office chair."]]]), statusCode: 200)
        }
        let transport = StubHTTPTransport(responses: responses)
        var results: [String: [Product]] = [:]
        try await FreeCatalogSearch(transport: transport, allowance: allowance).run(
            preferences: ProductExtractionKt.parseFixtureRequest(text: "chair under AED 400"), tavilyKey: "test-key",
            onStoreUpdate: { store, products, _ in results[store] = products }, onDiagnostic: { _ in }
        )

        XCTAssertEqual(transport.requests.count, 3)
        XCTAssertEqual(allowance.usedRequests, 3)
        XCTAssertEqual(results.values.flatMap { $0 }.count, 3)
        for request in transport.requests {
            XCTAssertEqual(request.url?.host, "api.tavily.com")
            XCTAssertEqual(request.url?.path, "/search", "Never request paid page extraction or an LLM from catalog retrieval")
            let body = try XCTUnwrap(try JSONSerialization.jsonObject(with: XCTUnwrap(request.httpBody)) as? [String: Any])
            XCTAssertEqual(body["search_depth"] as? String, "basic")
            XCTAssertEqual(body["auto_parameters"] as? Bool, false)
            XCTAssertEqual(body["include_answer"] as? Bool, false)
            XCTAssertEqual(body["include_raw_content"] as? Bool, false)
        }
        for product in results.values.flatMap({ $0 }) {
            XCTAssertTrue(product.issues.contains { $0.contains("search-result evidence only") })
        }
    }

    @MainActor
    func testFreeCatalogCapBlocksBeforeNetworkAndPersists() async throws {
        let suite = "RoomWise-CatalogCap-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let allowance = FreeCatalogAllowance(defaults: defaults)
        for _ in 0..<100 { try allowance.reserve(3) }
        let restored = FreeCatalogAllowance(defaults: defaults)
        XCTAssertEqual(restored.usedRequests, 300)
        let transport = StubHTTPTransport(responses: [])
        do {
            try await FreeCatalogSearch(transport: transport, allowance: restored).run(preferences: ProductExtractionKt.parseFixtureRequest(text: "chair"), tavilyKey: "test-key", onStoreUpdate: { _, _, _ in }, onDiagnostic: { _ in })
            XCTFail("An exhausted reservation allowance must block network dispatch")
        } catch FreeCatalogSearchError.localAllowanceReached {
            // Expected.
        }
        XCTAssertTrue(transport.requests.isEmpty)
    }

    @MainActor
    func testCatalogAllowanceRollsOverOnlyAtUTCMonthBoundary() throws {
        let suite = "RoomWise-CatalogMonth-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        var now = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-11-30T23:59:59Z"))
        let allowance = FreeCatalogAllowance(defaults: defaults, now: { now })
        try allowance.reserve(300)
        XCTAssertEqual(allowance.remainingRequests, 0)
        now = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-12-01T00:00:00Z"))
        XCTAssertEqual(allowance.remainingRequests, 300)
        try allowance.reserve(3)
        XCTAssertEqual(allowance.usedRequests, 3)
    }

    @MainActor
    func testCatalogProviderQuotaStopsWithoutRetryAndKeepsReservation() async throws {
        let suite = "RoomWise-CatalogProviderQuota-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let allowance = FreeCatalogAllowance(defaults: defaults)
        let transport = StubHTTPTransport(responses: [.init(data: Data("{}".utf8), statusCode: 402)])
        do {
            try await FreeCatalogSearch(transport: transport, allowance: allowance).run(preferences: ProductExtractionKt.parseFixtureRequest(text: "chair"), tavilyKey: "test-key", onStoreUpdate: { _, _, _ in }, onDiagnostic: { _ in })
            XCTFail("Provider quota must be surfaced")
        } catch FreeCatalogSearchError.providerLimitReached {
            // Expected.
        }
        XCTAssertEqual(transport.requests.count, 1, "A quota failure must not trigger another retailer request or retry")
        XCTAssertEqual(allowance.usedRequests, 3, "Reservations are conservative and never refunded after dispatch")
    }

    @MainActor
    func testCatalogCancellationKeepsAllThreeReservations() async throws {
        final class CancelledTransport: HTTPTransport {
            var requestCount = 0
            func send(request: URLRequest) async throws -> (Data, HTTPURLResponse) {
                requestCount += 1
                throw URLError(.cancelled)
            }
        }
        let suite = "RoomWise-CatalogCancellation-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let allowance = FreeCatalogAllowance(defaults: defaults)
        let transport = CancelledTransport()
        do {
            try await FreeCatalogSearch(transport: transport, allowance: allowance).run(preferences: ProductExtractionKt.parseFixtureRequest(text: "chair"), tavilyKey: "test-key", onStoreUpdate: { _, _, _ in }, onDiagnostic: { _ in })
            XCTFail("Cancellation must propagate")
        } catch is CancellationError {
            // Expected.
        }
        XCTAssertEqual(transport.requestCount, 1)
        XCTAssertEqual(allowance.usedRequests, 3)
    }

    @MainActor
    func testDeletingSavedRoomsDoesNotResetCatalogAllowance() throws {
        let quotaKey = "roomwise_free_catalog_allowance_v1"
        let defaults = UserDefaults.standard
        let priorValue = defaults.object(forKey: quotaKey)
        defer {
            if let value = priorValue { defaults.set(value, forKey: quotaKey) }
            else { defaults.removeObject(forKey: quotaKey) }
        }
        let allowance = FreeCatalogAllowance(defaults: defaults)
        let current = allowance.usedRequests
        if current <= 297 { try allowance.reserve(3) }
        let reserved = allowance.usedRequests

        RoomPersistence.clearSavedData()

        XCTAssertEqual(FreeCatalogAllowance(defaults: defaults).usedRequests, reserved)
    }

    func testUserEnteredListingProvenanceSurvivesRelaunch() throws {
        RoomPersistence.clearSavedData()
        defer { RoomPersistence.clearSavedData() }
        let fixture = try XCTUnwrap(DemoKt.demoProducts().first)
        let manual = fixture.doCopy(
            id: "manual-chair", retailer: fixture.retailer, title: "My saved chair",
            url: "https://www.amazon.ae/dp/B000000001", imageUrl: nil,
            price: nil, currency: nil, retrievedAt: "2026-11-01T00:00:00Z",
            variant: nil, seller: nil, dimensions: fixture.dimensions, features: [],
            delivery: nil, availability: nil, issues: [], source: "User-entered listing",
            savedDemo: false, provenance: ProductProvenance.userEntered
        )
        RoomPersistence.saveSession(room: DemoKt.demoRoom(), query: "chair", products: [manual], selectedProductId: manual.id, chairPose: Pose(x: 2, z: 2, yaw: 0), retailerStatuses: [:], sampleMode: false)

        let restored = try XCTUnwrap(RoomPersistence.loadSession()?.products.first)
        XCTAssertEqual(restored.provenance, ProductProvenance.userEntered)
        XCTAssertFalse(restored.savedDemo)
    }

    func testRetailerSearchQueryIsEncodedWithoutChangingDestination() throws {
        let query = "chair &url=https://evil.example/?x=1#fragment + café %2F"
        let stores: [(Retailer, String, String)] = [(.amazon, "www.amazon.ae", "k"), (.noon, "www.noon.com", "q"), (.temu, "www.temu.com", "search_key")]
        for (store, host, parameter) in stores {
            let url = try XCTUnwrap(RetailerCatalog.searchURL(store: store, query: query))
            let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
            XCTAssertEqual(components.scheme, "https")
            XCTAssertEqual(components.host, host)
            XCTAssertNil(components.fragment)
            XCTAssertEqual(components.queryItems?.count, 1)
            XCTAssertEqual(components.queryItems?.first?.name, parameter)
            XCTAssertEqual(components.queryItems?.first?.value, query)
        }
        XCTAssertNil(RetailerCatalog.searchURL(store: .amazon, query: "   "))
    }

    func testManualChairWithoutURLUsesOwnMeasurementsAndUserProvenance() throws {
        let dimensions = Dimensions(width: 0.6, depth: 0.65, height: 1.0)
        let product = try XCTUnwrap(RetailerCatalog.manualProduct(title: " My chair ", url: "", text: "", dimensions: dimensions))
        XCTAssertEqual(product.title, "My chair")
        XCTAssertEqual(product.retailer, "My measurements")
        XCTAssertEqual(product.url, "")
        XCTAssertEqual(product.provenance, .userEntered)
        XCTAssertFalse(product.savedDemo)
        XCTAssertEqual(product.dimensions?.origin, "user")
        XCTAssertEqual(product.dimensions?.kind, "assembled")
        XCTAssertEqual(product.previewSize()?.width, 0.6)
        XCTAssertTrue(product.issues.contains { $0.contains("not been independently checked") })
        XCTAssertNil(product.price)
    }

    func testManualChairRejectsMaliciousOrUnsupportedProductURLs() {
        let urls = ["javascript:alert(1)", "http://www.amazon.ae/dp/B000000001", "https://amazon.ae.evil.example/dp/B000000001", "https://evil.example/chair", "https://www.amazon.ae/s?k=chair", "https://www.noon.com/uae-en/privacy", "https://www.temu.com/"]
        for url in urls {
            XCTAssertNil(RetailerCatalog.manualProduct(title: "Chair", url: url, text: "", dimensions: nil), "Unsupported product destination must be rejected: \(url)")
        }
        XCTAssertNil(RetailerCatalog.manualProduct(title: "  ", url: "", text: "", dimensions: nil))
        XCTAssertNil(RetailerCatalog.manualProduct(title: "Chair", url: "", text: "", dimensions: Dimensions(width: -1, depth: 1, height: 1)))
    }

    // These hosted renders exercise real SwiftUI layout on Simulator without opening
    // the camera, invoking an AR session, or contacting a shopping provider. Attachments
    // are retained for visual inspection of both compact and larger iPhone layouts.
    @MainActor
    func testInitialScreenRendersAtCompactAndLargeIPhoneSizes() async throws {
        RoomPersistence.clearSavedData()
        defer { RoomPersistence.clearSavedData() }
        for (name, size) in renderViewports {
            try await attachHostedRender(ContentView(), size: size, name: "RoomWise initial screen - \(name)")
        }
    }

    @MainActor
    func testHelpPrivacyRendersWithBothConsentStates() async throws {
        for (index, viewport) in renderViewports.enumerated() {
            let help = HelpPrivacyView(
                liveSearchConsent: index == 1,
                onRevokeConsent: { XCTFail("Rendering privacy information must not revoke consent") },
                onDelete: { XCTFail("Rendering privacy information must not delete saved data") }
            )
            try await attachHostedRender(help, size: viewport.1, name: "Help and privacy - \(viewport.0) - consent \(index == 1 ? "allowed" : "off")")
        }
    }

    @MainActor
    func testDimensionEditorRendersFixtureValuesAtBothIPhoneSizes() async throws {
        let product = try XCTUnwrap(DemoKt.demoProducts().first)
        for (name, size) in renderViewports {
            let editor = EditDimensionsSheetView(product: product, onSave: { _ in
                XCTFail("Rendering the editor must not save or change a product")
            })
            try await attachHostedRender(editor, size: size, name: "Assembled dimension editor - \(name)")
        }
    }

    @MainActor
    func testFreeConnectionsRenderWithoutConfiguredKeys() async throws {
        let credentials = SessionCredentials(store: InMemoryCredentialStore())
        for (name, size) in renderViewports {
            try await attachHostedRender(FreeConnectionsSheetView(credentials: credentials), size: size, name: "Free provider connections - \(name)")
        }
        XCTAssertFalse(credentials.hasGroqKey)
        XCTAssertFalse(credentials.hasTavilyKey)
    }

    @MainActor
    func testAddChairFormRendersWithoutSavingOrNetwork() async throws {
        for (name, size) in renderViewports {
            let form = AddChairSheetView(onSave: { _ in XCTFail("Rendering a new-chair form must not save a product") })
            try await attachHostedRender(form, size: size, name: "Add your chair - \(name)")
        }
    }

    @MainActor
    func testSimplifiedARChairBoundsMatchAssembledDimensions() {
        for dimensions in [Dimensions(width: 0.62, depth: 0.64, height: 1.12),
                           Dimensions(width: 0.8, depth: 0.4, height: 1.6),
                           Dimensions(width: 0.1, depth: 0.12, height: 0.15)] {
            let node = makeChairNode(dimensions)
            let (minimum, maximum) = node.boundingBox
            XCTAssertEqual(Double(maximum.x - minimum.x), dimensions.width, accuracy: 0.00001)
            XCTAssertEqual(Double(maximum.z - minimum.z), dimensions.depth, accuracy: 0.00001)
            XCTAssertEqual(Double(maximum.y - minimum.y), dimensions.height, accuracy: 0.00001)
            XCTAssertEqual(Double(minimum.y), 0, accuracy: 0.00001, "Chair must rest on the raycast floor")
            XCTAssertEqual(Double(minimum.x + maximum.x), 0, accuracy: 0.00001)
            XCTAssertEqual(Double(minimum.z + maximum.z), 0, accuracy: 0.00001)
            XCTAssertEqual(node.scale.x, 1, "AR placement container must remain unscaled")
            XCTAssertEqual(node.scale.y, 1)
            XCTAssertEqual(node.scale.z, 1)
        }
    }

    private var renderViewports: [(String, CGSize)] {
        [("compact 375x812", CGSize(width: 375, height: 812)),
         ("large 430x932", CGSize(width: 430, height: 932))]
    }

    @MainActor
    private func attachHostedRender<Content: View>(_ content: Content, size: CGSize, name: String) async throws {
        let previousWindow = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
        let host = UIHostingController(rootView: content.preferredColorScheme(.light))
        let window = UIWindow(frame: CGRect(origin: .zero, size: size))
        window.overrideUserInterfaceStyle = .light
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer {
            window.isHidden = true
            window.rootViewController = nil
            previousWindow?.makeKey()
        }

        window.frame = CGRect(origin: .zero, size: size)
        host.view.frame = window.bounds
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
        // Yield the main actor so NavigationStack, Form/List, and Canvas finish
        // their initial layout/display transactions before the screenshot.
        try await Task.sleep(nanoseconds: 400_000_000)
        host.view.layoutIfNeeded()

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.white.setFill()
            context.cgContext.fill(CGRect(origin: .zero, size: size))
            if !host.view.drawHierarchy(in: host.view.bounds, afterScreenUpdates: true) {
                host.view.layer.render(in: context.cgContext)
            }
        }
        let attachment = XCTAttachment(image: image)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)

        let cgImage = try XCTUnwrap(image.cgImage, "Hosted render must produce an image")
        XCTAssertEqual(cgImage.width, Int(size.width), "Screenshot must use the requested viewport")
        XCTAssertEqual(cgImage.height, Int(size.height), "Screenshot must use the requested viewport")
        // Inspect actual pixels, not PNG byte count: a blank white/transparent
        // hosting view must fail even though it can still encode as a PNG.
        // Keep enough spatial detail to preserve thin form labels. A 32px
        // thumbnail averages legitimate compact text into its white background.
        let sampleSize = 128
        var pixels = [UInt8](repeating: 0, count: sampleSize * sampleSize * 4)
        let brightness = try pixels.withUnsafeMutableBytes { buffer in
            let context = try XCTUnwrap(CGContext(
                data: buffer.baseAddress, width: sampleSize, height: sampleSize, bitsPerComponent: 8,
                bytesPerRow: sampleSize * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ))
            context.interpolationQuality = .high
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: sampleSize, height: sampleSize))
            return stride(from: 0, to: buffer.count, by: 4).map {
                (Int(buffer[$0]) + Int(buffer[$0 + 1]) + Int(buffer[$0 + 2])) / 3
            }
        }
        XCTAssertGreaterThan((brightness.max() ?? 0) - (brightness.min() ?? 0), 30, "Rendered UI must have visible contrast")
        XCTAssertGreaterThan(brightness.filter { $0 < 220 }.count, 64, "Rendered UI must contain visible content, not an empty surface")
    }
}
