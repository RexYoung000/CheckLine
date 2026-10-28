import XCTest

@MainActor
final class AgentSafetyUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        if #available(iOS 27.0, *) { try XCUIDevice.shared.voiceOverService.disable() }
    }

    func testNegatedExpenseFromExplicitBudgetKeepsInputWithoutSaving() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-design-preview", "-design-screen", "record",
                               "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()
        let mode = app.buttons["wallet.task.switchMode"]
        XCTAssertTrue(mode.waitForExistence(timeout: 10))
        mode.tap()
        let input = app.descendants(matching: .any).matching(identifier: "wallet.agent.input").firstMatch
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        input.tap()
        input.typeText("没有花35元")
        app.buttons["wallet.agent.send"].tap()
        let clarify = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "想记哪笔消费")).firstMatch
        // A response must arrive before checking that no completion was shown.
        XCTAssertTrue(clarify.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label == %@", "已记下")).firstMatch.exists)
        XCTAssertFalse(app.buttons["确认记下"].exists)
        XCTAssertEqual(input.value as? String, "没有花35元")
        XCTAssertTrue(app.buttons["wallet.task.switchMode"].isHittable)
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "agent-negated-expense-remains-uncommitted"
        shot.lifetime = .keepAlways
        add(shot)
    }

    func testOfflineDateClarificationDoesNotSaveUntilDateIsAnswered() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-design-preview", "-design-screen", "record",
                               "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()
        let mode = app.buttons["wallet.task.switchMode"]
        XCTAssertTrue(mode.waitForExistence(timeout: 10))
        mode.tap()
        let input = app.descendants(matching: .any).matching(identifier: "wallet.agent.input").firstMatch
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        input.tap(); input.typeText("午餐35元，不是今天的")
        app.buttons["wallet.agent.send"].tap()
        XCTAssertTrue(app.datePickers.firstMatch.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label == %@", "已记下")).firstMatch.exists)
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "offline-date-requires-review"
        shot.lifetime = .keepAlways
        add(shot)
        input.tap(); input.typeText("昨天")
        app.buttons["wallet.agent.send"].tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label == %@", "已记下")).firstMatch.waitForExistence(timeout: 5), app.debugDescription)
        let undo = app.buttons.matching(NSPredicate(format: "label == %@", "撤销")).allElementsBoundByIndex.first { $0.isHittable }
        XCTAssertNotNil(undo)
        undo?.tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "已撤销")).firstMatch.waitForExistence(timeout: 5))
    }
}
