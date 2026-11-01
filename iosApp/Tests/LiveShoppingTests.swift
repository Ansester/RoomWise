import XCTest
import Network
import SceneKit
import FitCheckShared
@testable import FitCheck

final class LiveShoppingTests: XCTestCase {
    func testPairingLinkRejectsPublicHostsCredentialsAndWrongRoutes() throws {
        XCTAssertNoThrow(try PairingLink.validate("http://192.168.1.8:45678/session/0123456789abcdef0123456789abcdef"))
        XCTAssertNoThrow(try PairingLink.validate("http://roomwise.local:45678/session/0123456789abcdef0123456789abcdef"))
        for link in ["http://192.168.1.8.example.com:45678/session/0123456789abcdef0123456789abcdef", "https://192.168.1.8:45678/session/0123456789abcdef0123456789abcdef", "http://example.com:45678/session/0123456789abcdef0123456789abcdef", "http://user:secret@192.168.1.8:45678/session/0123456789abcdef0123456789abcdef", "http://192.168.1.8:45678/wrong/0123456789abcdef0123456789abcdef", "http://192.168.1.8:45678/session/0123456789abcdef0123456789abcdef?leak=1"] {
            XCTAssertThrowsError(try PairingLink.validate(link))
        }
    }
    func testWireSnapshotRetainsProductIdentityAndDimensions() throws {
        let products = DemoKt.demoProducts()
        let json = RoomBridge().encodeProducts(products: products)
        let data = Data("{\"schemaVersion\":1,\"revision\":7,\"products\":\(json),\"selectedProductId\":\"\(products[1].id)\"}".utf8)
        let result = try PairedShoppingSnapshot.decode(data)
        XCTAssertEqual(result.revision, 7)
        XCTAssertEqual(result.selectedProductId, products[1].id)
        XCTAssertEqual(result.products[1].previewSize()?.width, products[1].previewSize()?.width)
        XCTAssertThrowsError(try PairedShoppingSnapshot.decode(Data("{\"schemaVersion\":2,\"revision\":1,\"products\":[]}".utf8)))
        XCTAssertThrowsError(try PairedShoppingSnapshot.decode(Data("{\"schemaVersion\":1,\"revision\":1,\"products\":[],\"selectedProductId\":\"missing\"}".utf8)))
    }
    @MainActor func testARSelectionUpdatePreservesPlacementAndClearsUnknownSize() {
        let parent = SCNNode()
        let coordinator = ARFurniturePlacementView.Coordinator(dimensions: Dimensions(width: 0.5, depth: 0.6, height: 1))
        // Test the same replacement operation used by both tap placement and live updates.
        coordinator.place(dimensions: Dimensions(width: 0.5, depth: 0.6, height: 1), transform: SCNMatrix4MakeTranslation(2, 0, 3), in: parent)
        coordinator.updateDimensions(Dimensions(width: 0.8, depth: 0.7, height: 1.2), in: parent)
        XCTAssertEqual(parent.childNodes.count, 1)
        XCTAssertEqual(coordinator.placedNode?.position.x, 2)
        XCTAssertEqual(coordinator.placedNode?.position.z, 3)
        let bounds = coordinator.placedNode!.boundingBox
        XCTAssertEqual(bounds.max.x - bounds.min.x, 0.8, accuracy: 0.001)
        coordinator.updateDimensions(nil, in: parent)
        XCTAssertTrue(parent.childNodes.isEmpty)
        coordinator.updateDimensions(Dimensions(width: 0.4, depth: 0.5, height: 0.8), in: parent)
        XCTAssertEqual(parent.childNodes.count, 1)
        XCTAssertEqual(coordinator.placedNode?.position.x, 2)
        XCTAssertEqual(coordinator.placedNode?.position.z, 3)
    }
    func testRetailerPageIdentityDoesNotTreatDifferentProductsAsSame() {
        XCTAssertTrue(sameListingPage(URL(string: "https://amazon.ae/dp/ABC?tag=x")!, URL(string: "https://www.amazon.ae/dp/ABC")!))
        XCTAssertFalse(sameListingPage(URL(string: "https://www.amazon.ae/dp/ABC?variant=large")!, URL(string: "https://www.amazon.ae/dp/ABC?variant=small")!))
        XCTAssertFalse(sameListingPage(URL(string: "https://www.amazon.ae/dp/XYZ")!, URL(string: "https://www.amazon.ae/dp/ABC")!))
    }
    func testConversationStoreRoundTripsAndClearsAllContext() async throws {
        let turn = try await ShoppingConversation.reply(messages: [.init(role: "user", content: "white chair under AED 300")])
        ShoppingChatStore.save(messages: [.init(role: "user", content: "white chair under AED 300")], preferences: turn.preferences)
        XCTAssertEqual(ShoppingChatStore.loadMessages().last?.content, "white chair under AED 300")
        XCTAssertEqual(ShoppingChatStore.loadPreferences()?.budget?.doubleValue, 300)
        ShoppingChatStore.clear()
        XCTAssertTrue(ShoppingChatStore.loadMessages().isEmpty)
        XCTAssertNil(ShoppingChatStore.loadPreferences())
    }
}

private actor PairingTestTransport: HTTPTransport {
    private var revision: Int64 = 1
    private var selected: String
    private let productsJSON: String
    private var posted: [String] = []
    init(products: [Product]) {
        productsJSON = RoomBridge().encodeProducts(products: products)
        selected = products[0].id
    }
    func selectOnDesktop(_ id: String) { selected = id; revision += 1 }
    func selections() -> [String] { posted }
    func send(request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        if request.httpMethod == "POST" {
            let body = try JSONSerialization.jsonObject(with: request.httpBody!) as! [String: String]
            let target = body["productId"]!
            if posted.isEmpty { try await Task.sleep(nanoseconds: 180_000_000) }
            posted.append(target); selected = target; revision += 1
        }
        let data = Data("{\"schemaVersion\":1,\"revision\":\(revision),\"products\":\(productsJSON),\"selectedProductId\":\"\(selected)\"}".utf8)
        return (data, HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
    }
}

extension LiveShoppingTests {
    @MainActor private func awaitCondition(_ predicate: () -> Bool) async throws {
        for _ in 0..<150 {
            if predicate() { return }
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        XCTFail("Timed out waiting for paired session state")
    }
    @MainActor func testLivePhoneFollowsDesktopSelectionAndStopsOnDisconnect() async throws {
        let products = DemoKt.demoProducts()
        let transport = PairingTestTransport(products: products)
        let phone = LivePhoneSession(transport: transport)
        phone.connect(link: "http://127.0.0.1:45678/session/0123456789abcdef0123456789abcdef")
        try await awaitCondition { phone.isConnected }
        XCTAssertEqual(phone.selectedProductId, products[0].id)
        await transport.selectOnDesktop(products[1].id)
        try await awaitCondition { phone.selectedProductId == products[1].id }
        XCTAssertEqual(phone.products[1].previewSize()?.width, products[1].previewSize()?.width)
        phone.disconnect()
        await transport.selectOnDesktop(products[0].id)
        try await Task.sleep(nanoseconds: 450_000_000)
        XCTAssertFalse(phone.isConnected)
        XCTAssertEqual(phone.revision, -1)
    }
    @MainActor func testRapidSwipeBackSerializesFinalSelection() async throws {
        let products = DemoKt.demoProducts()
        let transport = PairingTestTransport(products: products)
        let phone = LivePhoneSession(transport: transport)
        phone.connect(link: "http://127.0.0.1:45678/session/0123456789abcdef0123456789abcdef")
        try await awaitCondition { phone.isConnected }
        phone.selectProduct(products[1].id)
        try await Task.sleep(nanoseconds: 30_000_000)
        phone.selectProduct(products[0].id)
        try await awaitCondition { phone.revision >= 3 }
        let posted = await transport.selections()
        XCTAssertEqual(posted, [products[1].id, products[0].id])
        XCTAssertEqual(phone.selectedProductId, products[0].id)
        phone.disconnect()
    }
}

// Actual loopback HTTP validates URLSession/ATS behavior and the native wire codec;
// unlike provider tests, this is a real local socket and never leaves the host.
private final class LocalPairingWireServer: @unchecked Sendable {
    private let listener: NWListener
    private let queue = DispatchQueue(label: "RoomWise.pairing-wire-test")
    private let lock = NSLock()
    private var state: [String: Any]
    private var startResolved = false
    init(products: [Product]) throws {
        listener = try NWListener(using: .tcp, on: .any)
        let encoded = RoomBridge().encodeProducts(products: products)
        state = ["schemaVersion": 1, "revision": 1, "products": try JSONSerialization.jsonObject(with: Data(encoded.utf8)), "selectedProductId": products[0].id]
    }
    func start() async throws -> String {
        listener.newConnectionHandler = { [weak self] connection in
            connection.start(queue: self?.queue ?? .global())
            self?.receive(connection, buffer: Data())
        }
        return try await withCheckedThrowingContinuation { continuation in
            listener.stateUpdateHandler = { [weak self] status in
                guard let self, !self.startResolved else { return }
                if case .ready = status, let port = self.listener.port {
                    self.startResolved = true
                    continuation.resume(returning: "http://127.0.0.1:\(port.rawValue)/session/0123456789abcdef0123456789abcdef")
                } else if case .failed(let error) = status {
                    self.startResolved = true; continuation.resume(throwing: error)
                }
            }
            listener.start(queue: queue)
        }
    }
    func select(_ id: String) {
        lock.lock(); defer { lock.unlock() }
        state["selectedProductId"] = id
        state["revision"] = (state["revision"] as! Int) + 1
    }
    func stop() { listener.cancel() }
    private func receive(_ connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) { [weak self] data, _, complete, error in
            guard let self else { connection.cancel(); return }
            var bytes = buffer; bytes.append(data ?? Data())
            guard bytes.count < 16_384, error == nil else { connection.cancel(); return }
            guard let divider = bytes.range(of: Data("\r\n\r\n".utf8)),
                  let header = String(data: bytes[..<divider.lowerBound], encoding: .utf8) else {
                if complete { connection.cancel() } else { self.receive(connection, buffer: bytes) }; return
            }
            let length = header.components(separatedBy: "\r\n").first(where: { $0.lowercased().hasPrefix("content-length:") })
                .flatMap { Int($0.split(separator: ":", maxSplits: 1)[1].trimmingCharacters(in: .whitespaces)) } ?? 0
            let body = Data(bytes[divider.upperBound...])
            guard body.count >= length else { self.receive(connection, buffer: bytes); return }
            if header.hasPrefix("POST"), let payload = try? JSONSerialization.jsonObject(with: body) as? [String: String], let id = payload["productId"] { self.select(id) }
            self.lock.lock()
            let responseBody = try! JSONSerialization.data(withJSONObject: self.state)
            self.lock.unlock()
            var response = Data("HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: \(responseBody.count)\r\nConnection: close\r\n\r\n".utf8)
            response.append(responseBody)
            connection.send(content: response, completion: .contentProcessed { _ in connection.cancel() })
        }
    }
}

extension LiveShoppingTests {
    @MainActor func testNativePhoneOverRealLocalHTTPFollowsAndSendsSelection() async throws {
        let products = DemoKt.demoProducts()
        let server = try LocalPairingWireServer(products: products)
        let link = try await server.start()
        defer { server.stop() }
        let phone = LivePhoneSession()
        defer { phone.disconnect() }
        phone.connect(link: link)
        try await awaitCondition { phone.isConnected }
        XCTAssertEqual(phone.selectedProductId, products[0].id)
        server.select(products[1].id)
        try await awaitCondition { phone.selectedProductId == products[1].id }
        phone.selectProduct(products[0].id)
        try await awaitCondition { phone.revision >= 3 && phone.selectedProductId == products[0].id }
        XCTAssertEqual(phone.products[0].previewSize()?.width, 0.62)
    }
}

extension LiveShoppingTests {
    /// Optional cross-runtime proof, started by scripts/check-live-pairing.sh.
    /// The JVM fixture host uses the real desktop session and shared Product serializer.
    @MainActor func testActualJVMDesktopPairing() async throws {
        guard let link = ProcessInfo.processInfo.environment["ROOMWISE_TEST_PAIRING_URL"], !link.isEmpty else {
            throw XCTSkip("Run scripts/check-live-pairing.sh for the actual JVM-to-native integration check.")
        }
        @MainActor func awaitActualState(_ description: String, _ predicate: () -> Bool) async throws {
            for _ in 0..<400 {
                if predicate() { return }
                try await Task.sleep(nanoseconds: 20_000_000)
            }
            XCTFail("Actual JVM pairing did not reach \(description).")
            throw PairingError.disconnected
        }
        let phone = LivePhoneSession() // Actual URLSession transport, with the app's ATS configuration.
        defer { phone.disconnect() }
        phone.connect(link: link)
        try await awaitActualState("initial fixture A") { phone.isConnected && phone.selectedProductId == "fixture-a" }
        XCTAssertEqual(phone.products.count, 3)
        XCTAssertEqual(phone.products[0].provenance, .fixture)
        XCTAssertEqual(phone.products[0].previewSize()?.width, 0.62)

        phone.selectProduct("fixture-b")
        try await awaitActualState("phone POST selecting fixture B") { phone.selectedProductId == "fixture-b" && phone.revision >= 2 }
        XCTAssertEqual(phone.products.first(where: { $0.id == "fixture-b" })?.previewSize()?.width, 0.56)

        // The Java harness publishes C only after receiving B through the real JVM host.
        try await awaitActualState("desktop publication of fixture C") { phone.selectedProductId == "fixture-c" && phone.revision >= 3 }
        XCTAssertNil(phone.products.first(where: { $0.id == "fixture-c" })?.previewSize())
    }
}
