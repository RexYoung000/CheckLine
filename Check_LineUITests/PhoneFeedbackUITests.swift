import XCTest

@MainActor
final class PhoneFeedbackUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        if #available(iOS 27.0, *) { try XCUIDevice.shared.voiceOverService.disable() }
    }

    func testBudgetExplainsMissingNameAndInvalidLimitBeforeSaving() {
        let app = launch("budget-empty")
        XCTAssertTrue(app.buttons["wallet.empty.card"].waitForExistence(timeout: 10))
        app.buttons["wallet.empty.card"].tap()
        let amount = app.textFields["额度"]
        XCTAssertTrue(amount.waitForExistence(timeout: 5))
        amount.tap(); amount.typeText("500")
        dismissKeyboard(app)
        let save = app.buttons["wallet.composer.save"]
        XCTAssertFalse(save.isEnabled)
        XCTAssertTrue(app.staticTexts["还需要填写预算名称"].exists)
        attach(app, "budget-limit-needs-name")

        let name = app.textFields["wallet.composer.name"]
        name.tap(); name.typeText("Named budget")
        dismissKeyboard(app)
        XCTAssertTrue(save.isEnabled)
        XCTAssertFalse(app.staticTexts["wallet.composer.validation"].exists)

        amount.coordinate(withNormalizedOffset: CGVector(dx: 0.98, dy: 0.5)).tap()
        amount.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 6) + "0")
        XCTAssertEqual(amount.value as? String, "0")
        dismissKeyboard(app)
        XCTAssertFalse(save.isEnabled)
        XCTAssertTrue(app.staticTexts["额度需填写大于 0 的数字"].exists)
        amount.coordinate(withNormalizedOffset: CGVector(dx: 0.98, dy: 0.5)).tap()
        amount.typeText(XCUIKeyboardKey.delete.rawValue + "500")
        XCTAssertEqual(amount.value as? String, "500")
        dismissKeyboard(app)
        XCTAssertTrue(save.isEnabled)
        attach(app, "budget-named-and-ready")
        save.tap()
        XCTAssertTrue(name.waitForNonExistence(timeout: 5))
        let saved = app.descendants(matching: .any)["wallet.home.card"].firstMatch
        XCTAssertTrue(saved.staticTexts["Named budget"].waitForExistence(timeout: 5))
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
        dismissKeyboard(app)
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
        XCTAssertTrue(app.staticTexts["每月 1 日起，至下月同日前"].exists)
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
        let saved = app.descendants(matching: .any)["wallet.home.card"].firstMatch
        XCTAssertTrue(saved.staticTexts["Weekend plan"].waitForExistence(timeout: 5), app.debugDescription)
        saved.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.3)).tap()
        let manage = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "卡片信息与管理")).firstMatch
        scrollToReach(manage, in: app)
        XCTAssertTrue(app.buttons["wallet.workspace.records"].exists)
        manage.tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "一次性")).firstMatch.waitForExistence(timeout: 5))
        attach(app, "phone-feedback-budget-saved-after-keeping-draft")
    }

    func testWishKeepsSelectedUSDCurrencyAndExplainsBalance() {
        let app = launch("wishes")
        let add = app.buttons["wallet.header.create"]
        XCTAssertTrue(add.waitForExistence(timeout: 10), app.debugDescription)
        add.tap()
        let name = app.textFields["wallet.wishes.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText("USD Wish")
        dismissKeyboard(app)
        let amount = app.textFields["wallet.wishes.estimate"]
        scrollToReach(amount, in: app)
        amount.tap()
        amount.typeText("49.50")
        dismissKeyboard(app)
        let currency = app.buttons["wallet.wishes.currency"]
        scrollToReach(currency, in: app)
        currency.tap()
        let usd = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "USD")).firstMatch
        XCTAssertTrue(usd.waitForExistence(timeout: 5), app.debugDescription)
        usd.tap()
        XCTAssertEqual(currency.value as? String, "USD")
        attach(app, "phone-feedback-wish-form-selected-usd")

        app.buttons["wallet.wishes.create.save"].tap()
        XCTAssertTrue(name.waitForNonExistence(timeout: 5))
        app.buttons["native.wish.layout"].tap()
        let saved = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label == %@", "native.wish.card.", "USD Wish")).firstMatch
        XCTAssertTrue(saved.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue((saved.value as? String)?.contains("$49.5") == true,
                      "The saved estimate must use the selected USD currency.")
        attach(app, "phone-feedback-saved-wish-dollar-estimate")
        let wishID = saved.identifier
        saved.tap()
        let expanded = app.descendants(matching: .any)["native.wish.expanded"].firstMatch
        XCTAssertTrue(expanded.waitForExistence(timeout: 5))
        let card = expanded.descendants(matching: .any)[wishID].firstMatch
        card.coordinate(withNormalizedOffset: CGVector(dx: 0.16, dy: 0.45)).tap()
        let redeem = expanded.buttons["native.wish.redeem"].firstMatch
        let reference = expanded.buttons["native.wish.checkRate"].firstMatch
        XCTAssertTrue(reference.waitForExistence(timeout: 5))
        XCTAssertFalse(redeem.isEnabled)
        reference.tap()
        let rate = app.textFields["wallet.exchange.rate"]
        XCTAssertTrue(rate.waitForExistence(timeout: 5))
        rate.tap(); rate.typeText("7")
        dismissKeyboard(app)
        app.buttons["native.wish.applyReference"].tap()
        let redeemable = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == true AND enabled == true"), object: redeem)
        XCTAssertEqual(XCTWaiter.wait(for: [redeemable], timeout: 5), .completed)
        redeem.tap()
        let purchaseCurrency = app.buttons["wallet.wishes.purchaseCurrency"]
        XCTAssertTrue(purchaseCurrency.waitForExistence(timeout: 5))
        XCTAssertEqual(purchaseCurrency.value as? String, "USD", "The saved wish currency must carry through to a real purchase.")
        app.navigationBars["兑现心愿"].buttons["关闭"].tap()
        XCTAssertTrue(purchaseCurrency.waitForNonExistence(timeout: 5))
        expanded.buttons["关闭"].tap()

        let balance = app.buttons["native.wish.balance"]
        XCTAssertTrue(balance.waitForExistence(timeout: 5), app.debugDescription)
        balance.tap()
        let detail = app.staticTexts["wallet.wishes.balance.detail"]
        XCTAssertTrue(detail.waitForExistence(timeout: 5))
        XCTAssertEqual(detail.value as? String, "¥860", "Creating a wish and checking a reference rate must leave the funded wallet unchanged.")
        attach(app, "phone-feedback-wish-balance-summary")
        let about = app.buttons["wallet.wishes.balance.about"]
        scrollToReach(about, in: app)
        about.tap()
        XCTAssertTrue(app.staticTexts["这里记录预算结余的去向，不代表银行卡中的真实余额。"].waitForExistence(timeout: 5))
        attach(app, "phone-feedback-wish-balance-expanded-rules")
    }

    func testCalendarRequiresACreatedBudgetAndShowsItsPeriod() {
        let app = launch("budget-empty")
        let create = app.buttons["wallet.empty.card"]
        XCTAssertTrue(create.waitForExistence(timeout: 10), app.debugDescription)
        XCTAssertFalse(app.buttons["上个月"].exists)
        XCTAssertFalse(app.buttons["下个月"].exists)
        attach(app, "phone-feedback-analysis-without-dates")
        create.tap()
        let name = app.textFields["输入预算名称"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText("Review card")
        dismissKeyboard(app)
        let amount = app.textFields["额度"]
        amount.tap()
        amount.typeText("400")
        dismissKeyboard(app)
        app.buttons["wallet.composer.save"].tap()
        XCTAssertTrue(name.waitForNonExistence(timeout: 5))
        XCTAssertFalse(create.exists)
        let card = app.descendants(matching: .any)["wallet.home.card"].firstMatch
        XCTAssertTrue(card.staticTexts["Review card"].waitForExistence(timeout: 5), app.debugDescription)
        card.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.3)).tap()
        let calendar = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "消费日历")).firstMatch
        scrollToReach(calendar, in: app)
        calendar.tap()
        XCTAssertTrue(app.buttons["上个月"].waitForExistence(timeout: 5), "Only a real budget period should expose the calendar.")
        XCTAssertTrue(app.staticTexts["当天暂无记录"].exists)
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
        let workspace = app.scrollViews["wallet.workspace.page"].firstMatch
        let scrollView = workspace.exists ? workspace : app.scrollViews.firstMatch
        for _ in 0..<6 where !element.isHittable { scrollView.swipeUp() }
        XCTAssertTrue(element.isHittable, app.debugDescription)
    }

    private func attach(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
