import XCTest

/// Run only in the dedicated, newly-created Cloud QA simulator with private provisioning.
@MainActor final class CloudAgentLiveUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    func testConsentLiveClarificationAttributionSaveAndRestart() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["CHECKLINE_LIVE_AGENT_UI"] == "1",
            "Requires explicit live-test opt-in and a dedicated empty, privately provisioned simulator.")
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()
        let create = app.buttons["wallet.empty.createBudget"]
        if create.waitForExistence(timeout: 8) {
            create.tap()
            let name = app.textFields["wallet.composer.name"]
            XCTAssertTrue(name.waitForExistence(timeout: 5)); name.tap(); name.typeText("Cloud QA")
            finishKeyboard(app)
            let amount = app.textFields["额度"]
            XCTAssertTrue(amount.waitForExistence(timeout: 5)); amount.tap(); amount.typeText("600")
            finishKeyboard(app)
            let save = app.buttons["wallet.composer.save"]
            XCTAssertTrue(save.isEnabled); save.tap()
        }
        let avatar = app.buttons["wallet.agent.avatar"]
        XCTAssertTrue(avatar.waitForExistence(timeout: 8)); avatar.tap()
        let input = app.descendants(matching: .any).matching(identifier: "wallet.agent.input").firstMatch
        XCTAssertTrue(input.waitForExistence(timeout: 8)); input.tap(); input.typeText("记一笔午餐")
        app.buttons["wallet.agent.send"].tap()
        let consent = app.alerts["让小朵使用云端理解？"]
        if consent.waitForExistence(timeout: 4) {
            attach(app, "cloud-first-send-consent")
            consent.buttons["启用并发送"].tap()
        }
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "金额是多少")).firstMatch.waitForExistence(timeout: 20), app.debugDescription)
        attach(app, "cloud-live-amount-question")
        input.tap(); input.typeText("35元"); app.buttons["wallet.agent.send"].tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "放到哪张预算卡")).firstMatch.waitForExistence(timeout: 5), app.debugDescription)
        let choice = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "cloud.agent.budget.")).firstMatch
        reach(choice, in: app); XCTAssertTrue(choice.isHittable); choice.tap()
        let confirm = app.buttons["确认记下"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 8), app.debugDescription); reach(confirm, in: app)
        attach(app, "cloud-live-inline-budget-confirmation")
        confirm.tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "已记下")).firstMatch.waitForExistence(timeout: 8), app.debugDescription)
        attach(app, "cloud-live-saved")
        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons["wallet.agent.avatar"].waitForExistence(timeout: 8))
        app.buttons["wallet.agent.avatar"].tap()
        let reopened = app.descendants(matching: .any).matching(identifier: "wallet.agent.input").firstMatch
        XCTAssertTrue(reopened.waitForExistence(timeout: 5)); reopened.tap(); reopened.typeText("昨天咖啡12元")
        app.buttons["wallet.agent.send"].tap()
        XCTAssertFalse(app.alerts["让小朵使用云端理解？"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "放到哪张预算卡")).firstMatch.waitForExistence(timeout: 20), app.debugDescription)
        attach(app, "cloud-keychain-connection-after-restart")
    }
    private func finishKeyboard(_ app: XCUIApplication) {
        let done = app.buttons["完成输入"].firstMatch
        if done.waitForExistence(timeout: 2), done.isHittable { done.tap() }
    }
    private func reach(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<5 where !element.isHittable { app.scrollViews.allElementsBoundByIndex.last(where: \.isHittable)?.swipeUp() }
    }
    private func attach(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
}
