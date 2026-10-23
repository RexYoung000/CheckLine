import XCTest

@MainActor final class EarlySettlementUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        #if targetEnvironment(simulator)
        if #available(iOS 27.0, *) { try XCUIDevice.shared.voiceOverService.disable() }
        #endif
    }
    func testEarlySettlementCancellationCommitAndWaitingPeriod() {
        let app = XCUIApplication()
        app.launchArguments = ["-design-preview", "-design-screen", "r34-home", "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()
        let card = app.descendants(matching: .any)["wallet.home.card"].firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 10))
        card.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.3)).tap()
        let settle = app.buttons["wallet.budget.settlement"]
        XCTAssertTrue(settle.waitForExistence(timeout: 5))
        XCTAssertTrue(settle.label.contains("提前结算"), app.debugDescription)
        if !settle.isHittable { app.swipeUp() }
        settle.tap()
        let schedule = app.staticTexts["settlement.early.schedule"]
        XCTAssertTrue(schedule.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(schedule.label.contains("间隔内"))
        let confirm = app.buttons["wallet.settlement.confirm"]
        XCTAssertFalse(confirm.isEnabled)
        attach(app, "early-settlement-schedule-and-unconfirmed-impact")
        app.navigationBars["提前结算"].buttons.matching(NSPredicate(format: "label == %@", "关闭")).firstMatch.tap()
        XCTAssertTrue(settle.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["wallet.budget.record"].isEnabled, "Cancelling must leave the current period open.")
        settle.tap()
        let accept = app.buttons["wallet.settlement.acceptData"]
        XCTAssertTrue(accept.waitForExistence(timeout: 5)); accept.tap()
        XCTAssertTrue(confirm.isEnabled); confirm.tap()
        let result = app.descendants(matching: .any)["native.outcome.result"].firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(app.buttons["native.outcome.skip"].waitForNonExistence(timeout: 8))
        attach(app, "early-settlement-receiving-result")
        app.buttons["回到预算"].tap()
        XCTAssertTrue(result.waitForNonExistence(timeout: 5))
        let record = app.buttons["wallet.budget.record"]
        XCTAssertTrue(record.waitForExistence(timeout: 5)); XCTAssertFalse(record.isEnabled)
        XCTAssertFalse(settle.label.contains("提前结算"), "A future period must not offer another early settlement.")
        settle.tap()
        XCTAssertTrue(app.staticTexts["wallet.settlement.estimateOnly"].waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertFalse(confirm.exists)
        attach(app, "early-settlement-next-period-waits-for-original-date")
    }
    private func attach(_ app: XCUIApplication, _ name: String) {
        let image = XCTAttachment(screenshot: app.screenshot())
        image.name = name; image.lifetime = .keepAlways; add(image)
    }
}
