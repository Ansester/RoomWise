import XCTest

/// Touch-driven smoke coverage of the real SwiftUI shopping loop. No provider,
/// retailer, camera, physical device, or network account is used by these tests.
final class ConnectedShoppingUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-roomwise-ui-testing"]
        app.launch()
    }

    func testOngoingConversationKeepsEarlierTurns() {
        send("white chair under AED 300")
        send("make it black under AED 400")
        let conversation = app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@", "Conversation (4)")).firstMatch
        XCTAssertTrue(conversation.waitForExistence(timeout: 10), "Both user turns and both assistant replies should be retained.")

        let history = app.scrollViews["shopping-conversation-history"]
        reveal(history)
        for _ in 0..<4 where !app.staticTexts["white chair under AED 300"].isHittable { history.swipeDown() }
        XCTAssertTrue(app.staticTexts["white chair under AED 300"].exists)
        for _ in 0..<4 where !app.staticTexts["make it black under AED 400"].isHittable { history.swipeUp() }
        XCTAssertTrue(app.staticTexts["make it black under AED 400"].exists)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "chair under AED 400")).firstMatch.exists,
                      "The assistant should apply the new budget while preserving an ongoing conversation.")
        capture("ongoing-conversation")
    }

    func testSwipingShoppingPagesUpdatesStickyPreviewAndUnknownSize() {
        send("chair")
        let find = app.buttons["Find matches"]
        reveal(find); find.tap()
        let title = app.staticTexts["live-preview-title"]
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        XCTAssertEqual(title.label, "Fixture A · Black task chair")

        let next = app.buttons["Next shopping page"]
        reveal(next)
        let pages = app.descendants(matching: .any)["shopping-product-pages"].firstMatch
        reveal(pages)
        pages.swipeLeft()
        waitForLabel(title, "Fixture B · Compact desk chair")
        XCTAssertFalse(app.staticTexts["live-preview-missing-size"].exists)
        capture("shopping-page-live-preview")

        reveal(next); next.tap()
        waitForLabel(title, "Fixture C · Chair with unknown assembled size")
        XCTAssertTrue(app.staticTexts["live-preview-missing-size"].waitForExistence(timeout: 5),
                      "A listing without assembled dimensions must remove the previous object's rendering.")
        capture("unknown-size-clears-preview")

        let previous = app.buttons["Previous shopping page"]
        reveal(previous); previous.tap()
        waitForLabel(title, "Fixture B · Compact desk chair")
        XCTAssertFalse(app.staticTexts["live-preview-missing-size"].exists)
    }

    private func send(_ message: String) {
        let input = app.descendants(matching: .any)["shopping-chat-input"].firstMatch
        reveal(input)
        input.tap(); input.typeText(message)
        let done = app.buttons["Done"].firstMatch
        if done.exists && done.isHittable { done.tap() }
        let send = app.buttons["Send"]
        reveal(send); send.tap()
        let find = app.buttons["Find matches"]
        let ready = NSPredicate(format: "enabled == true")
        expectation(for: ready, evaluatedWith: find)
        waitForExpectations(timeout: 15)
    }

    private func reveal(_ element: XCUIElement) {
        XCTAssertTrue(element.waitForExistence(timeout: 10))
        let workspace = app.scrollViews["shopping-workspace"]
        for _ in 0..<5 {
            if element.isHittable { return }
            workspace.swipeUp()
        }
        for _ in 0..<5 {
            if element.isHittable { return }
            workspace.swipeDown()
        }
        XCTAssertTrue(element.isHittable, "The requested shopping control should be reachable.")
    }

    private func waitForLabel(_ element: XCUIElement, _ label: String) {
        expectation(for: NSPredicate(format: "label == %@", label), evaluatedWith: element)
        waitForExpectations(timeout: 10)
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
