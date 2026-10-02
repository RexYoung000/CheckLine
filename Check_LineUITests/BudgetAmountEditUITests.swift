import XCTest

@MainActor
final class BudgetAmountEditUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    func testBudgetAmountPreviewCancelAndConfirmedOverrun() throws {
        let app = launch()
        openEditor(app)
        replaceAmount(app, "1600.25")
        app.buttons["wallet.budget.edit.preview"].tap()
        XCTAssertTrue(app.buttons["wallet.budget.edit.save"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["确定超支（仅已确认）"].exists)
        XCTAssertTrue(app.staticTexts["可能额外超支（待确认）"].exists)
        XCTAssertTrue(app.staticTexts["以后每月额度"].exists)
        attach(app, "budget-edit-certain-and-possible-overrun")
        app.buttons["wallet.budget.edit.back"].tap()
        let field = app.textFields["wallet.budget.edit.amount"]
        XCTAssertEqual(field.value as? String, "1600.25")
        app.buttons["wallet.budget.edit.cancel"].tap()
        openEditor(app)
        XCTAssertEqual(field.value as? String, "1600.25", "Cancelling must keep the in-memory input draft without saving the budget.")
        replaceAmount(app, "1600.25")
        app.buttons["wallet.budget.edit.preview"].tap()
        app.buttons["wallet.budget.edit.save"].tap()
        XCTAssertTrue(app.buttons["wallet.budget.edit.save"].waitForNonExistence(timeout: 5))
        openEditor(app)
        XCTAssertEqual(field.value as? String, "1600.25")
        app.buttons["wallet.budget.edit.cancel"].tap()
        attach(app, "budget-edit-saved-home")
    }

    func testInvalidPrecisionPendingOnlyAndReduceMotion() throws {
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
        attach(app, "budget-edit-pending-only-reduce-motion")
        app.buttons["wallet.budget.edit.save"].tap()
        XCTAssertTrue(app.buttons["wallet.budget.edit.save"].waitForNonExistence(timeout: 5))
        attach(app, "budget-edit-reduce-motion-home")
    }

    func testBudgetListEntryAndRecordSuccessRemainUsable() throws {
        let app = launch()
        let more = app.buttons["wallet.home.card.more"]
        XCTAssertTrue(more.waitForExistence(timeout: 10))
        app.buttons["wallet.tab.budgets"].tap()
        let budgetMenu = app.buttons.matching(identifier: "wallet.budget.card.more").firstMatch
        XCTAssertTrue(budgetMenu.waitForExistence(timeout: 5))
        budgetMenu.tap()
        app.buttons["调整月度额度"].tap()
        XCTAssertTrue(app.textFields["wallet.budget.edit.amount"].waitForExistence(timeout: 5))
        app.buttons["wallet.budget.edit.cancel"].tap()
        app.buttons["wallet.tab.home"].tap()
        app.buttons["记一笔"].firstMatch.tap()
        let field = app.textFields["输入金额"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap(); field.typeText("25.25")
        app.buttons["wallet.composer.save"].tap()
        XCTAssertTrue(field.waitForNonExistence(timeout: 5))
        attach(app, "budget-edit-record-success-home")
    }

    private func launch(reduceMotion: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-design-preview", "-design-screen", "home", "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        if reduceMotion { app.launchArguments.append("-design-reduce-motion") }
        app.launch()
        return app
    }

    private func openEditor(_ app: XCUIApplication) {
        let more = app.buttons["wallet.home.card.more"]
        XCTAssertTrue(more.waitForExistence(timeout: 10))
        more.tap()
        let edit = app.buttons["调整月度额度"]
        XCTAssertTrue(edit.waitForExistence(timeout: 5))
        edit.tap()
        XCTAssertTrue(app.textFields["wallet.budget.edit.amount"].waitForExistence(timeout: 5))
    }

    private func replaceAmount(_ app: XCUIApplication, _ amount: String) {
        let field = app.textFields["wallet.budget.edit.amount"]
        field.tap()
        let current = field.value as? String ?? ""
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count) + amount)
    }

    private func attach(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways
        add(attachment)
    }
}
