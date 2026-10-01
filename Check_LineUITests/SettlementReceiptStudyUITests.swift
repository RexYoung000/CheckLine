import XCTest

@MainActor
final class SettlementReceiptStudyUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    func testReplayCanBeInterruptedAndScenarioChangedWithoutLosingResult() {
        let app = launch()
        let replay = app.buttons["receipt.replay"]
        XCTAssertTrue(replay.waitForExistence(timeout: 8))
        for _ in 0..<3 { replay.tap() }
        app.buttons["receipt.finish"].tap()
        XCTAssertTrue(app.staticTexts["receipt.amount"].isHittable)
        XCTAssertTrue(app.staticTexts["receipt.amount"].label.contains("532"))
        attach(app, "receipt-surplus-interrupted")

        app.segmentedControls["receipt.scenario"].buttons["越线示例"].tap()
        app.buttons["receipt.finish"].tap()
        XCTAssertTrue(app.staticTexts["receipt.amount"].label.contains("240"))
        attach(app, "receipt-overrun")
        replay.tap()
        app.buttons["receipt.close"].tap()
        XCTAssertTrue(app.buttons["receipt.open"].waitForExistence(timeout: 5))
        app.buttons["receipt.open"].tap()
        app.buttons["receipt.finish"].tap()
        XCTAssertTrue(app.staticTexts["receipt.amount"].label.contains("240"))
    }

    func testReducedMotionImmediatelyShowsFullResultAndKeepsScenarioUsable() {
        let app = launch(reduced: true)
        XCTAssertTrue(app.descendants(matching: .any)["receipt.static"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.buttons["receipt.replay"].exists)
        XCTAssertTrue(app.staticTexts["receipt.amount"].isHittable)
        app.segmentedControls["receipt.scenario"].buttons["越线示例"].tap()
        XCTAssertTrue(app.staticTexts["receipt.amount"].label.contains("240"))
        attach(app, "receipt-reduced-motion")
    }

    func testLargeTextCanScrollToTheEndOfReceiptWithControlsReachable() {
        let app = launch(reduced: true)
        XCTAssertTrue(app.staticTexts["receipt.amount"].waitForExistence(timeout: 8))
        let note = app.staticTexts["心愿钱包是账本结果，不是真实资金。"]
        for _ in 0..<6 {
            if note.isHittable { break }
            app.scrollViews.firstMatch.swipeUp()
        }
        XCTAssertTrue(note.isHittable, app.debugDescription)
        XCTAssertTrue(app.buttons["receipt.close"].isHittable)
        XCTAssertTrue(app.segmentedControls["receipt.scenario"].isHittable)
        attach(app, "receipt-large-text-scrolled")
    }

    private func launch(reduced: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-design-preview", "-design-screen", "settlement-receipt", "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        if reduced { app.launchArguments.append("-design-reduce-motion") }
        app.launch()
        return app
    }

    private func attach(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
}
