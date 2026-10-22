import XCTest

/// Real commit paths, intentionally allowing the full native reward to finish.
/// The parent runner records the simulator; these tests do not replay or skip.
@MainActor final class NativeMotionEvidenceUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        if #available(iOS 27.0, *) { try XCUIDevice.shared.voiceOverService.disable() }
    }

    func testWishPurchasePlaysCompleteRevealBeforeViewingRealized() {
        let app = launch("redemption")
        let amount = app.textFields["wallet.wishes.actual"]
        XCTAssertTrue(amount.waitForExistence(timeout: 10), app.debugDescription)
        amount.tap(); amount.typeText("300")
        app.buttons["完成输入"].firstMatch.tap()
        let purchase = app.switches["wallet.wishes.purchaseConfirmed"]
        reveal(purchase, in: app); purchase.tap()
        let confirm = app.buttons["wallet.wishes.confirm"]
        XCTAssertTrue(confirm.isEnabled); confirm.tap()

        let result = app.descendants(matching: .any)["native.outcome.result"].firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 5), app.debugDescription)
        waitForCompleteMotion(in: app)
        XCTAssertTrue(app.buttons["查看已实现"].isHittable)
        attach(app, "r34-wish-full-reveal-finished")
        app.buttons["查看已实现"].tap()
        XCTAssertTrue(result.waitForNonExistence(timeout: 5), app.debugDescription)
    }

    func testSettlementPlaysAllReceivingBeatsInCurrentPageBeforeReturn() {
        let app = launch("settlement-loop")
        app.staticTexts["周末旅行"].firstMatch.tap()
        let settle = app.buttons["wallet.budget.settlement"]
        XCTAssertTrue(settle.waitForExistence(timeout: 8), app.debugDescription)
        reveal(settle, in: app); settle.tap()
        let accept = app.buttons["wallet.settlement.acceptData"]
        XCTAssertTrue(accept.waitForExistence(timeout: 5), app.debugDescription)
        reveal(accept, in: app); accept.tap()
        app.buttons["wallet.settlement.confirm"].tap()

        let result = app.descendants(matching: .any)["native.outcome.result"].firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 5), app.debugDescription)
        waitForCompleteMotion(in: app)
        XCTAssertTrue(app.staticTexts["周末旅行"].exists,
                      "The full receipt must still identify the budget that was settled.")
        XCTAssertTrue(app.buttons["回到预算"].isHittable)
        let wallet = app.descendants(matching: .any)["native.outcome.wallet"].firstMatch
        XCTAssertTrue(wallet.isHittable,"The receiving amount must remain visible above the fixed action.")
        XCTAssertLessThanOrEqual(wallet.frame.maxY,app.buttons["回到预算"].frame.minY+2,"The fixed action must not cover the receiving wallet.")
        attach(app, "r34-settlement-six-beats-finished-current-page")
        app.buttons["回到预算"].tap()
        XCTAssertTrue(result.waitForNonExistence(timeout: 5), app.debugDescription)
    }

    private func waitForCompleteMotion(in app: XCUIApplication) {
        // This button exists only until the receipt's own 3.2 s / 2.75 s
        // presentation clock completes. Never tap it in a recording path.
        XCTAssertTrue(app.buttons["native.outcome.skip"].waitForNonExistence(timeout: 8),
                      "The native reward must reach its stable saved result without a skip.", file: #filePath, line: #line)
    }

    private func launch(_ screen: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-design-preview", "-design-screen", screen, "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()
        return app
    }

    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<8 {
            if element.isHittable { return }
            app.scrollViews.firstMatch.swipeUp(velocity: .slow)
        }
        XCTAssertTrue(element.isHittable, app.debugDescription)
    }

    private func attach(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name; shot.lifetime = .keepAlways; add(shot)
    }
}
