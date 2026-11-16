import XCTest

@MainActor
final class EmptyStateRefinementUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        if #available(iOS 27.0, *) { try XCUIDevice.shared.voiceOverService.disable() }
    }

    func testEmptyHomeKeepsAgentAndManualBudgetEntries() {
        let app = launch("empty")
        let firstCard = app.buttons["wallet.empty.card"]
        let manual = app.buttons["手动填写"]
        XCTAssertTrue(firstCard.waitForExistence(timeout: 10), app.debugDescription)
        let nativeAgent = app.tabBars.buttons.matching(NSPredicate(format: "label CONTAINS %@", "小朵")).firstMatch
        let agent = nativeAgent.exists ? nativeAgent : app.buttons["wallet.agent.avatar"].firstMatch
        XCTAssertTrue(firstCard.isHittable)
        XCTAssertTrue(agent.isHittable)
        XCTAssertTrue(manual.isHittable)
        XCTAssertFalse(app.staticTexts["为日常开销或一个计划，创建一张预算卡。"].exists)
        attach(app, "empty-home-agent-and-secondary-manual")

        agent.tap()
        XCTAssertTrue(app.descendants(matching: .any)["wallet.agent.input"].waitForExistence(timeout: 5), app.debugDescription)
        app.buttons["wallet.agent.close"].tap()
        XCTAssertTrue(manual.waitForExistence(timeout: 5))
        manual.tap()
        XCTAssertTrue(app.textFields["输入预算名称"].waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(app.textFields["额度"].exists)
        app.buttons["wallet.composer.close"].tap()
        XCTAssertTrue(firstCard.waitForExistence(timeout: 5))
        XCTAssertTrue(firstCard.isHittable)
        XCTAssertTrue(agent.isHittable)
        XCTAssertTrue(manual.isHittable)
    }

    func testEmptyBudgetRetainsCalendarBrowsingCoverageAndRecordEntry() {
        let app = launch("budget-empty")
        let create = app.buttons["wallet.empty.card"]
        XCTAssertTrue(create.waitForExistence(timeout: 10), app.debugDescription)
        create.tap()
        let name = app.textFields["wallet.composer.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap(); name.typeText("Calendar Review")
        app.buttons["wallet.keyboard.done"].tap()
        let amount = app.textFields["wallet.composer.amount"]
        amount.tap(); amount.typeText("500")
        app.buttons["wallet.keyboard.done"].tap()
        let save = app.buttons["wallet.composer.save"]
        XCTAssertTrue(save.isEnabled)
        save.tap()
        XCTAssertTrue(name.waitForNonExistence(timeout: 5))

        let card = app.descendants(matching: .any)["wallet.home.card"].firstMatch
        XCTAssertTrue(card.staticTexts["Calendar Review"].waitForExistence(timeout: 10), app.debugDescription)
        card.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.3)).tap()
        let calendar = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "消费日历")).firstMatch
        reveal(calendar, in: app)
        calendar.tap()
        let previousMonth = app.buttons["上个月"]
        XCTAssertTrue(previousMonth.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["当天暂无记录"].exists)
        XCTAssertFalse(app.staticTexts["-¥0"].exists)
        attach(app, "analysis-empty-action-with-calendar")

        previousMonth.tap()
        let outsidePeriod = app.staticTexts["所选日期不在本周期"]
        XCTAssertTrue(outsidePeriod.waitForExistence(timeout: 5), app.debugDescription)
        app.buttons["下个月"].tap()
        XCTAssertTrue(outsidePeriod.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["当天暂无记录"].exists)

        let coverage = app.buttons["数据覆盖"]
        for _ in 0..<4 where !coverage.isHittable { app.swipeUp() }
        XCTAssertTrue(coverage.isHittable, app.debugDescription)
        coverage.tap()
        XCTAssertTrue(app.staticTexts["仅展示已录入的消费；空白日期不代表没有消费。"].waitForExistence(timeout: 5), app.debugDescription)
        attach(app, "analysis-empty-date-and-coverage")

        app.navigationBars["消费日历"].buttons.firstMatch.tap()
        let records = app.buttons["wallet.workspace.records"]
        reveal(records, in: app)
        records.tap()
        let empty = app.staticTexts["还没有记到这张卡的消费"]
        XCTAssertTrue(empty.waitForExistence(timeout: 5), app.debugDescription)
        let record = app.buttons["记一笔"].firstMatch
        reveal(record, in: app)
        record.tap()
        let input = app.textFields["输入金额"]
        XCTAssertTrue(input.waitForExistence(timeout: 5), app.debugDescription)
        app.buttons["wallet.composer.close"].tap()
        XCTAssertTrue(input.waitForNonExistence(timeout: 5))
        XCTAssertTrue(card.staticTexts["Calendar Review"].waitForExistence(timeout: 5))
        card.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.3)).tap()
        reveal(records, in: app)
        records.tap()
        XCTAssertTrue(empty.waitForExistence(timeout: 5), "Cancelling the recording must leave the original budget empty.")
    }

    private func launch(_ screen: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-design-preview", "-design-screen", screen, "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()
        return app
    }

    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        let workspace = app.scrollViews["wallet.workspace.page"].firstMatch
        let scrollView = workspace.exists ? workspace : app.scrollViews.firstMatch
        for _ in 0..<5 where !element.isHittable { scrollView.swipeUp() }
        XCTAssertTrue(element.isHittable, app.debugDescription)
    }

    private func attach(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
