import XCTest

@MainActor
final class BudgetAmountEditUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        #if targetEnvironment(simulator)
        if #available(iOS 27.0, *) { try XCUIDevice.shared.voiceOverService.disable() }
        #endif
    }

    func testBudgetAmountPreviewCancelAndConfirmedOverrun() {
        let app = launch()
        openEditor(app)
        replaceAmount(app, "1600.25")
        app.buttons["wallet.budget.edit.preview"].tap()
        XCTAssertTrue(app.buttons["wallet.budget.edit.save"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["确定超支（仅已确认）"].exists)
        XCTAssertTrue(app.staticTexts["可能额外超支（待确认）"].exists)
        XCTAssertTrue(element("wallet.budget.edit.newRecurringAmount", in: app).label.contains("本期及以后每期"))
        attach(app, "budget-limit-monthly-confirmed-and-pending-overrun")
        app.buttons["wallet.budget.edit.back"].tap()
        let field = app.textFields["wallet.budget.edit.amount"]
        XCTAssertEqual(field.value as? String, "1600.25")
        app.buttons["wallet.budget.edit.cancel"].tap()
        openEditor(app)
        XCTAssertEqual(field.value as? String, "1600.25", "Cancelling preserves input without changing the limit.")
        app.buttons["wallet.budget.edit.preview"].tap()
        app.buttons["wallet.budget.edit.save"].tap()
        XCTAssertTrue(app.buttons["wallet.budget.edit.save"].waitForNonExistence(timeout: 5))
        XCTAssertTrue(element("wallet.budget.limit.amount", in: app).label.contains("1,600.25"))
        openEditor(app)
        XCTAssertEqual(field.value as? String, "1600.25")
        app.buttons["wallet.budget.edit.cancel"].tap()
        attach(app, "budget-limit-monthly-saved-detail")
    }

    func testInvalidPrecisionPendingOnlyAndReduceMotion() {
        let app = launch(reduceMotion: true)
        openEditor(app)
        replaceAmount(app, "0.001")
        app.buttons["wallet.budget.edit.preview"].tap()
        XCTAssertTrue(app.staticTexts["wallet.budget.edit.error"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.textFields["wallet.budget.edit.amount"].value as? String, "0.001")
        XCTAssertFalse(app.buttons["wallet.budget.edit.save"].exists)
        replaceAmount(app, "1700.25")
        app.buttons["wallet.budget.edit.preview"].tap()
        XCTAssertTrue(app.buttons["wallet.budget.edit.save"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["确定超支（仅已确认）"].exists)
        XCTAssertTrue(app.staticTexts["可能额外超支（待确认）"].exists)
        attach(app, "budget-limit-pending-only-reduce-motion")
        app.buttons["wallet.budget.edit.save"].tap()
        XCTAssertTrue(app.buttons["wallet.budget.edit.save"].waitForNonExistence(timeout: 5))
        XCTAssertTrue(element("wallet.budget.limit.amount", in: app).label.contains("1,700.25"))
    }

    func testDirectLimitEditThenRecordReturnsToUsableHome() {
        let app = launch()
        openEditor(app)
        app.buttons["wallet.budget.edit.cancel"].tap()
        let record = app.buttons["wallet.budget.record"]
        reveal(record, in: app); record.tap()
        let field = app.textFields["输入金额"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap(); field.typeText("25.25")
        app.buttons["wallet.keyboard.done"].tap()
        app.buttons["wallet.composer.save"].tap()
        XCTAssertTrue(field.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.buttons["wallet.home.capture"].isHittable)
        let native = app.tabBars.buttons["预算"].firstMatch
        XCTAssertTrue(native.exists ? native.isHittable : app.buttons["wallet.tab.budgets"].isHittable)
        attach(app, "budget-limit-cancel-record-return")
    }

    func testOneShotLimitShowsOnlyThisBudgetAndUpdatesHome() {
        let app = launch("limit-one-shot")
        openEditor(app)
        XCTAssertTrue(element("wallet.budget.edit.scope", in: app).label.contains("仅本次"))
        XCTAssertTrue(element("wallet.budget.edit.periodDates", in: app).label.contains("截止"))
        replaceAmount(app, "30.25")
        app.buttons["wallet.budget.edit.preview"].tap()
        XCTAssertTrue(app.buttons["wallet.budget.edit.save"].waitForExistence(timeout: 5))
        XCTAssertTrue(element("wallet.budget.edit.newAmount", in: app).label.contains("30.25"))
        XCTAssertFalse(element("wallet.budget.edit.newRecurringAmount", in: app).exists)
        XCTAssertTrue(app.staticTexts["确定超支（仅已确认）"].exists)
        attach(app, "budget-limit-one-shot-impact")
        app.buttons["wallet.budget.edit.save"].tap()
        XCTAssertTrue(app.buttons["wallet.budget.edit.save"].waitForNonExistence(timeout: 5))
        XCTAssertTrue(element("wallet.budget.limit.amount", in: app).label.contains("30.25"))
        app.buttons["wallet.budget.detail.close"].tap()
        XCTAssertTrue(app.buttons["wallet.home.capture"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "4.75")).firstMatch.exists)
        attach(app, "budget-limit-one-shot-home-overrun")
    }

    func testWeeklyLimitUpdatesSettlementEstimate() { checkRecurringLimit("limit-weekly") }
    func testCustomLimitUpdatesSettlementEstimate() { checkRecurringLimit("limit-custom") }

    private func checkRecurringLimit(_ screen: String) {
        let app = launch(screen)
        openEditor(app)
        XCTAssertTrue(element("wallet.budget.edit.scope", in: app).label.contains("以后每期"))
        replaceAmount(app, "150.25")
        app.buttons["wallet.budget.edit.preview"].tap()
        XCTAssertTrue(app.buttons["wallet.budget.edit.save"].waitForExistence(timeout: 5))
        XCTAssertTrue(element("wallet.budget.edit.newRecurringAmount", in: app).label.contains("150.25"))
        attach(app, screen + "-impact")
        app.buttons["wallet.budget.edit.save"].tap()
        XCTAssertTrue(app.buttons["wallet.budget.edit.save"].waitForNonExistence(timeout: 5))
        XCTAssertTrue(element("wallet.budget.limit.amount", in: app).label.contains("150.25"))
        let settle = app.buttons["wallet.budget.settlement"]
        reveal(settle, in: app); settle.tap()
        XCTAssertTrue(app.buttons["wallet.settlement.confirm"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["wallet.settlement.confirm"].isEnabled)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "115.25")).firstMatch.exists)
        attach(app, screen + "-settlement-estimate")
    }

    private func launch(_ screen: String = "r34-home", reduceMotion: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-design-preview", "-design-screen", screen, "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        if reduceMotion { app.launchArguments.append("-design-reduce-motion") }
        app.launch()
        return app
    }

    private func openEditor(_ app: XCUIApplication) {
        let edit = app.buttons["wallet.budget.limit.edit"]
        if !edit.exists {
            let card = element("wallet.home.card", in: app)
            XCTAssertTrue(card.waitForExistence(timeout: 10))
            card.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.3)).tap()
        }
        XCTAssertTrue(edit.waitForExistence(timeout: 5))
        reveal(edit, in: app); edit.tap()
        XCTAssertTrue(app.textFields["wallet.budget.edit.amount"].waitForExistence(timeout: 5))
    }

    private func replaceAmount(_ app: XCUIApplication, _ amount: String) {
        let field = app.textFields["wallet.budget.edit.amount"]
        field.tap()
        let current = field.value as? String ?? ""
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count) + amount)
    }

    private func element(_ id: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }
    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<6 {
            if element.isHittable { return }
            app.swipeUp(velocity: .slow)
        }
    }
    private func attach(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
}
