import XCTest

@MainActor
final class EmptyStateRefinementUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        if #available(iOS 27.0, *) { try XCUIDevice.shared.voiceOverService.disable() }
    }

    func testEmptyHomeKeepsAgentAndManualBudgetEntries() {
        let app = launch("empty")
        let agentCard = app.buttons["wallet.empty.card"]
        let manual = app.buttons["wallet.empty.createBudget"]
        XCTAssertTrue(agentCard.waitForExistence(timeout: 10), app.debugDescription)
        XCTAssertTrue(agentCard.isHittable)
        XCTAssertTrue(manual.isHittable)
        XCTAssertFalse(app.staticTexts["为日常开销或一个计划，创建一张预算卡。"].exists)
        attach(app, "empty-home-agent-and-secondary-manual")

        agentCard.tap()
        XCTAssertTrue(app.descendants(matching: .any)["wallet.agent.input"].waitForExistence(timeout: 5), app.debugDescription)
        app.buttons["wallet.agent.close"].tap()
        XCTAssertTrue(manual.waitForExistence(timeout: 5))
        manual.tap()
        XCTAssertTrue(app.textFields["输入预算名称"].waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(app.textFields["额度"].exists)
        app.buttons["wallet.composer.close"].tap()
        XCTAssertTrue(agentCard.waitForExistence(timeout: 5))
        XCTAssertTrue(agentCard.isHittable)
        XCTAssertTrue(manual.isHittable)
    }

    func testAnalysisWithoutRecordsRetainsDateBrowsingAndCoverage() {
        let app = launch("analysis-no-records")
        let record = app.buttons["wallet.analysis.empty.record"]
        XCTAssertTrue(record.waitForExistence(timeout: 10), app.debugDescription)
        XCTAssertTrue(app.staticTexts["还没有消费记录"].exists)
        XCTAssertFalse(app.staticTexts["本期已用"].exists)
        XCTAssertFalse(app.staticTexts["-¥0"].exists)
        let previousMonth = app.buttons["上个月"]
        XCTAssertTrue(previousMonth.isHittable)
        attach(app, "analysis-empty-action-with-calendar")

        previousMonth.tap()
        let outsidePeriod = app.staticTexts["所选日期不在本周期"]
        XCTAssertTrue(outsidePeriod.waitForExistence(timeout: 5), app.debugDescription)
        app.buttons["下个月"].tap()
        XCTAssertTrue(outsidePeriod.waitForNonExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["当天暂无记录"].exists)

        let coverage = app.buttons["数据覆盖"]
        for _ in 0..<4 where !coverage.isHittable { app.swipeUp() }
        XCTAssertTrue(coverage.isHittable, app.debugDescription)
        coverage.tap()
        XCTAssertTrue(app.staticTexts["仅展示已录入的消费；空白日期不代表没有消费。"].waitForExistence(timeout: 5), app.debugDescription)
        attach(app, "analysis-empty-date-and-coverage")

        for _ in 0..<4 where !record.isHittable { app.swipeDown() }
        XCTAssertTrue(record.isHittable, app.debugDescription)
        record.tap()
        XCTAssertTrue(app.textFields["输入金额"].waitForExistence(timeout: 5), app.debugDescription)
        app.buttons["wallet.composer.close"].tap()
        XCTAssertTrue(record.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["还没有消费记录"].exists)
    }

    private func launch(_ screen: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-design-preview", "-design-screen", screen, "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()
        return app
    }

    private func attach(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
