import XCTest

@MainActor
final class AgentConversationUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        if #available(iOS 27.0, *) { try XCUIDevice.shared.voiceOverService.disable() }
    }

    func testMissingAmountKeepsConversationAndInputThroughSaveAndUndo() throws {
        let app = launchAgent()
        let input = app.descendants(matching: .any).matching(identifier: "wallet.agent.input").firstMatch
        XCTAssertTrue(input.waitForExistence(timeout: 10), app.debugDescription)
        input.tap()
        input.typeText("记一笔CoffeeUITest")
        app.buttons["wallet.agent.send"].tap()

        XCTAssertTrue(message("金额是多少？", in: app).waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertFalse(app.buttons["确认记下"].exists)
        XCTAssertTrue(input.isHittable)
        attach(app, "agent-missing-amount-stays-in-conversation")

        input.tap()
        input.typeText("35 元")
        app.buttons["wallet.agent.send"].tap()
        let confirm = app.buttons["确认记下"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(input.exists)
        XCTAssertTrue(app.buttons["wallet.agent.send"].exists)
        XCTAssertFalse(app.buttons["wallet.composer.save"].exists)
        reveal(confirm, in: app)
        XCTAssertTrue(confirm.isHittable, app.debugDescription)
        attach(app, "agent-inline-confirmation-keeps-input")
        confirm.tap()

        XCTAssertTrue(message("已记下", in: app).waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertFalse(confirm.exists)
        let undo = try XCTUnwrap(app.buttons.matching(NSPredicate(format: "label == %@", "撤销"))
            .allElementsBoundByIndex.first(where: { $0.isHittable }))
        undo.tap()
        XCTAssertTrue(message("已撤销", in: app).waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(input.exists)
        attach(app, "agent-saved-and-undone-within-task")
    }

    func testCancellingFirstVoiceExplanationPreservesUnsentInput() {
        let app = launchAgent(resetMicrophone: true)
        let input = app.descendants(matching: .any).matching(identifier: "wallet.agent.input").firstMatch
        XCTAssertTrue(input.waitForExistence(timeout: 10), app.debugDescription)
        input.tap()
        input.typeText("Voice cancel 35 USD")
        app.buttons["wallet.agent.voice"].tap()

        let notice = app.alerts["用语音告诉小朵"]
        XCTAssertTrue(notice.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(notice.buttons["开始语音输入"].exists)
        attach(app, "voice-first-use-explanation-before-permission")
        notice.buttons["取消"].tap()
        XCTAssertTrue(notice.waitForNonExistence(timeout: 5))
        XCTAssertEqual(input.value as? String, "Voice cancel 35 USD")
        XCTAssertFalse(app.buttons["确认记下"].exists)
        XCTAssertFalse(message("已记下", in: app).exists)
        XCTAssertTrue(app.buttons["wallet.agent.send"].isEnabled)
        attach(app, "voice-explanation-cancel-keeps-unsent-text")
    }

    private func launchAgent(resetMicrophone: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        if resetMicrophone { app.resetAuthorizationStatus(for: .microphone) }
        app.launchArguments = ["-design-preview", "-design-screen", "agent",
                               "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()
        return app
    }

    private func message(_ text: String, in app: XCUIApplication) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
    }

    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<5 where !element.isHittable {
            guard let scroll = app.scrollViews.allElementsBoundByIndex.last(where: { $0.isHittable }) else { return }
            scroll.swipeUp()
        }
    }

    private func attach(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
