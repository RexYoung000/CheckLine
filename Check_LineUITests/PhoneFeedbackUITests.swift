import XCTest

@MainActor
final class PhoneFeedbackUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        if #available(iOS 27.0, *) { try XCUIDevice.shared.voiceOverService.disable() }
    }

    func testBudgetCycleAndCancelledDiscardKeepInputBeforeSaving() {
        let app = launch("budget-empty")
        let create = app.buttons["wallet.empty.card"]
        XCTAssertTrue(create.waitForExistence(timeout: 10), app.debugDescription)
        create.tap()
        let name = app.textFields["输入预算名称"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        let help = app.buttons["wallet.task.switchMode"]
        XCTAssertTrue(help.isHittable)
        XCTAssertEqual(help.label, "请小朵帮我填")
        XCTAssertGreaterThan(help.frame.midX, app.frame.midX, "The help entry should sit at the right of the header area.")

        name.tap()
        name.typeText("Weekend plan")
        let amount = app.textFields["额度"]
        amount.tap()
        amount.typeText("600")
        dismissKeyboard(app)

        let cycle = app.segmentedControls["wallet.composer.cycle"]
        XCTAssertTrue(cycle.waitForExistence(timeout: 5), app.debugDescription)
        cycle.buttons["一次性"].tap()
        XCTAssertTrue(cycle.buttons["一次性"].isSelected)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "完成后主动结算")).firstMatch.exists)
        cycle.buttons["每月循环"].tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "月底结束，按月循环")).firstMatch.exists)
        cycle.buttons["一次性"].tap()
        attach(app, "phone-feedback-budget-form-and-native-cycle")

        app.buttons["wallet.task.options"].tap()
        app.buttons["放弃这份草稿"].tap()
        let alert = app.alerts["清除未保存的内容？"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertEqual(alert.buttons.matching(identifier: "放弃草稿").count, 1)
        attach(app, "phone-feedback-discard-single-action")
        alert.buttons["保留草稿"].tap()
        XCTAssertEqual(name.value as? String, "Weekend plan")
        XCTAssertEqual(amount.value as? String, "600")
        XCTAssertTrue(cycle.buttons["一次性"].isSelected)

        app.buttons["wallet.composer.save"].tap()
        XCTAssertTrue(name.waitForNonExistence(timeout: 5))
        let saved = app.buttons["Weekend plan"].firstMatch
        XCTAssertTrue(saved.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "一次性")).firstMatch.exists)
        saved.tap()
        XCTAssertTrue(app.buttons["wallet.workspace.records"].waitForExistence(timeout: 5))
        attach(app, "phone-feedback-budget-saved-after-keeping-draft")
    }

    func testWishKeepsSelectedUSDCurrencyAndExplainsBalance() {
        let app = launch("wishes-empty")
        let add = app.buttons["wallet.wishes.empty.add"]
        XCTAssertTrue(add.waitForExistence(timeout: 10), app.debugDescription)
        add.tap()
        let name = app.textFields["wallet.wishes.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText("USD Wish")
        let amount = app.textFields["wallet.wishes.estimate"]
        amount.tap()
        amount.typeText("49.50")
        dismissKeyboard(app)
        let currency = app.buttons["wallet.wishes.currency"]
        currency.tap()
        let usd = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "USD")).firstMatch
        XCTAssertTrue(usd.waitForExistence(timeout: 5), app.debugDescription)
        usd.tap()
        XCTAssertEqual(currency.value as? String, "USD")
        attach(app, "phone-feedback-wish-form-selected-usd")

        app.buttons["wallet.wishes.create.save"].tap()
        XCTAssertTrue(name.waitForNonExistence(timeout: 5))
        let saved = app.staticTexts["USD Wish"]
        XCTAssertTrue(saved.waitForExistence(timeout: 5), app.debugDescription)
        saved.tap()
        XCTAssertTrue(app.navigationBars["心愿详情"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "$49.5")).firstMatch.exists,
                      "The saved estimate must display the selected dollars, not the wallet's CNY.")
        attach(app, "phone-feedback-saved-wish-dollar-estimate")
        app.buttons["已购买，去兑现"].tap()
        let purchaseCurrency = app.textFields["wallet.wishes.purchaseCurrency"]
        XCTAssertTrue(purchaseCurrency.waitForExistence(timeout: 5))
        XCTAssertEqual(purchaseCurrency.value as? String, "USD", "The saved wish currency must carry through to a real purchase.")
        app.navigationBars["兑现心愿"].buttons["关闭"].tap()
        XCTAssertTrue(app.navigationBars["心愿详情"].waitForExistence(timeout: 5))
        app.navigationBars["心愿详情"].buttons.firstMatch.tap()

        let balance = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "心愿余额")).firstMatch
        XCTAssertTrue(balance.waitForExistence(timeout: 5), app.debugDescription)
        balance.tap()
        let detail = app.staticTexts["wallet.wishes.balance.detail"]
        XCTAssertTrue(detail.waitForExistence(timeout: 5))
        XCTAssertEqual(detail.value as? String, "¥0", "Creating a wish must not reserve or deduct the wallet balance.")
        attach(app, "phone-feedback-wish-balance-summary")
        let about = app.buttons["wallet.wishes.balance.about"]
        scrollToReach(about, in: app)
        about.tap()
        XCTAssertTrue(app.staticTexts["这里记录预算结余的去向，不代表银行卡中的真实余额。"].waitForExistence(timeout: 5))
        attach(app, "phone-feedback-wish-balance-expanded-rules")
    }

    func testAnalysisWithoutBudgetCreatesCardBeforeShowingDates() {
        let app = launch("analysis-empty")
        let create = app.buttons["wallet.analysis.empty.createBudget"]
        XCTAssertTrue(create.waitForExistence(timeout: 10), app.debugDescription)
        XCTAssertFalse(app.buttons["上个月"].exists)
        XCTAssertFalse(app.buttons["下个月"].exists)
        attach(app, "phone-feedback-analysis-without-dates")
        create.tap()
        let name = app.textFields["输入预算名称"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText("Review card")
        let amount = app.textFields["额度"]
        amount.tap()
        amount.typeText("400")
        dismissKeyboard(app)
        app.buttons["wallet.composer.save"].tap()
        XCTAssertTrue(name.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.buttons["wallet.analysis.empty.record"].waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertFalse(create.exists)
        XCTAssertTrue(app.buttons["上个月"].exists, "Only a real budget period should expose the calendar.")
        XCTAssertTrue(app.staticTexts["还没有消费记录"].exists)
        attach(app, "phone-feedback-analysis-real-period-after-creation")
    }

    private func launch(_ screen: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-design-preview", "-design-screen", screen,
                               "-checkline.appearance", "light", "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()
        return app
    }

    private func dismissKeyboard(_ app: XCUIApplication) {
        let done = app.buttons["完成输入"].firstMatch
        if done.waitForExistence(timeout: 2), done.isHittable { done.tap() }
    }

    private func scrollToReach(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<4 where !element.isHittable { app.swipeUp() }
        XCTAssertTrue(element.isHittable, app.debugDescription)
    }

    private func attach(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
