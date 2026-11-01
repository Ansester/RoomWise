import XCTest
import Foundation
import FitCheckShared
@testable import FitCheck

private final class ConversationStub: HTTPTransport {
    var requests: [URLRequest] = []
    let status: Int
    let content: String
    var cancelled = false
    init(status: Int = 200, content: String = #"{"reply":"I kept mesh and changed the colour. What budget works?","budget":300,"currency":"AED","colour":"white","requiredFeatures":["mesh"],"maxWidthMetres":null,"maxDepthMetres":null}"#) {
        self.status = status; self.content = content
    }
    func send(request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requests.append(request)
        if cancelled { throw URLError(.cancelled) }
        let data = try JSONSerialization.data(withJSONObject: ["choices": [["message": ["content": content]]]])
        return (data, HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: nil)!)
    }
}

final class ShoppingConversationTests: XCTestCase {
    func testLocalConversationPreservesAndOverridesEarlierRequirements() async throws {
        let first = try await ShoppingConversation.reply(messages: [.init(role: "user", content: "black mesh chair under AED 400 with armrests")])
        let second = try await ShoppingConversation.reply(messages: [.init(role: "user", content: "make it white, under 300, no armrests")], previous: first.preferences)
        XCTAssertEqual(second.preferences.colour, "white")
        XCTAssertEqual(second.preferences.budget?.doubleValue, 300)
        XCTAssertTrue(second.preferences.requiredFeatures.contains("mesh"))
        XCTAssertTrue(second.preferences.requiredFeatures.contains("without armrests"))
        XCTAssertFalse(second.preferences.requiredFeatures.contains("armrests"))
        XCTAssertTrue(second.engineLabel.contains("no LLM"))
        let third = try await ShoppingConversation.reply(messages: [.init(role: "user", content: "remove budget and any colour")], previous: second.preferences)
        XCTAssertNil(third.preferences.budget); XCTAssertNil(third.preferences.colour)
        XCTAssertTrue(third.preferences.requiredFeatures.contains("mesh"))
    }

    func testVagueRefinementAsksAndExplicitDimensionsKeepUnits() async throws {
        let previous = ProductExtractionKt.parseFixtureRequest(text: "chair under 400")
        let cheaper = try await ShoppingConversation.reply(messages: [.init(role: "user", content: "cheaper please")], previous: previous)
        XCTAssertEqual(cheaper.preferences.budget?.doubleValue, 400)
        XCTAssertTrue(cheaper.reply.contains("maximum budget"))
        let smaller = try await ShoppingConversation.reply(messages: [.init(role: "user", content: "something narrower")], previous: previous)
        XCTAssertNil(smaller.preferences.maxWidth)
        XCTAssertTrue(smaller.reply.contains("maximum width"))
        let specified = try await ShoppingConversation.reply(messages: [.init(role: "user", content: "maximum width 55 cm and depth 24 inches")], previous: previous)
        XCTAssertEqual(specified.preferences.maxWidth!.doubleValue, 0.55, accuracy: 1e-9)
        XCTAssertEqual(specified.preferences.maxDepth!.doubleValue, 0.6096, accuracy: 1e-9)
        XCTAssertEqual(specified.preferences.budget?.doubleValue, 400)
    }

    func testHostedTurnSendsBoundedConversationAndAcceptedSnapshotOnce() async throws {
        let transport = ConversationStub()
        let messages = (1...20).map { ShoppingChatMessage(role: $0 % 2 == 0 ? "user" : "assistant", content: "turn\($0) " + String(repeating: "x", count: 1600)) }
        let previous = ProductExtractionKt.parseFixtureRequest(text: "black chair under 350 with armrests")
        let result = try await ShoppingConversation.reply(messages: messages, previous: previous, groqKey: "fake-key", transport: transport)
        XCTAssertEqual(transport.requests.count, 1)
        let request = transport.requests[0]
        XCTAssertEqual(request.url?.host, "api.groq.com")
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: request.httpBody!) as? [String: Any])
        let wire = try XCTUnwrap(body["messages"] as? [[String: String]])
        XCTAssertEqual(wire.count, 13)
        XCTAssertTrue(wire.dropFirst().allSatisfy { $0["content"]!.count <= 1500 })
        XCTAssertTrue(wire[1]["content"]!.hasPrefix("turn9"))
        XCTAssertTrue(wire[0]["content"]!.contains("350"))
        XCTAssertNil(body["tools"])
        XCTAssertFalse(String(decoding: request.httpBody!, as: UTF8.self).contains("fake-key"))
        XCTAssertEqual(result.preferences.colour, "white")
        XCTAssertEqual(result.preferences.budget?.doubleValue, 300)
        XCTAssertTrue(result.engineLabel.contains("Groq"))
    }

    func testQuotaAndInvalidOutputFallBackWithoutRetry() async throws {
        for transport in [ConversationStub(status: 429), ConversationStub(content: "{}"), ConversationStub(content: #"{"reply":"Updated","budget":-10,"currency":"AED","colour":"white","requiredFeatures":[],"maxWidthMetres":null,"maxDepthMetres":null}"#)] {
            let result = try await ShoppingConversation.reply(messages: [.init(role: "user", content: "make it white")], previous: ProductExtractionKt.parseFixtureRequest(text: "chair under 400"), groqKey: "fake-key", transport: transport)
            XCTAssertEqual(transport.requests.count, 1)
            XCTAssertEqual(result.preferences.budget?.doubleValue, 400)
            XCTAssertEqual(result.preferences.colour, "white")
            XCTAssertTrue(result.engineLabel.contains("Offline"))
        }
    }

    func testUnsupportedConnectionDoesNotCallProvider() async throws {
        let transport = ConversationStub()
        let result = try await ShoppingConversation.reply(messages: [.init(role: "user", content: "blue chair")], groqKey: "fake-key", model: "unsupported", transport: transport)
        XCTAssertTrue(transport.requests.isEmpty)
        XCTAssertEqual(result.preferences.colour, "blue")
        XCTAssertTrue(result.engineLabel.contains("Offline"))
    }

    func testCancellationIsNotAnOfflineAssistantResponse() async throws {
        let transport = ConversationStub(); transport.cancelled = true
        do {
            _ = try await ShoppingConversation.reply(messages: [.init(role: "user", content: "chair")], groqKey: "fake-key", transport: transport)
            XCTFail("Cancellation must propagate")
        } catch is CancellationError { }
    }

    func testEmptyTurnIsRejected() async throws {
        do {
            _ = try await ShoppingConversation.reply(messages: [.init(role: "assistant", content: "Hello")])
            XCTFail("An assistant-only conversation cannot start another request")
        } catch FreeShoppingParseError.emptyRequest { }
    }
}
