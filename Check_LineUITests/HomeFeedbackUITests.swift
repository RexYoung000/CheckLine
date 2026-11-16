import XCTest
import XCUIAutomation

@MainActor
final class HomeFeedbackUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        if #available(iOS 27.0, *) { try XCUIDevice.shared.voiceOverService.disable() }
    }

    func testOverdueBudgetOpensWorkspaceAndReturnsToSameCard() {
        let app = launch("home-overdue")
        let used = app.buttons["native.home.summary.used"]
        XCTAssertTrue(used.waitForExistence(timeout: 10))
        let originalFrame = used.frame
        used.tap()
        let detail = app.navigationBars["周末旅行"]
        XCTAssertTrue(detail.waitForExistence(timeout: 5))
        XCTAssertFalse(budgetTab(in: app).isHittable)
        XCTAssertTrue(app.staticTexts["待结算"].exists)
        XCTAssertTrue(app.buttons["wallet.budget.settlement"].exists)
        let records = app.buttons["wallet.workspace.records"]
        reveal(records, in: app)
        attach(app, "overdue-budget-workspace")

        records.tap()
        XCTAssertTrue(app.segmentedControls.firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["还没有记到这张卡的消费"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(detail.waitForExistence(timeout: 5))
        app.buttons["wallet.budget.detail.close"].tap()
        XCTAssertTrue(used.waitForExistence(timeout: 5))
        XCTAssertTrue(used.isHittable)
        XCTAssertEqual(used.frame.minY, originalFrame.minY, accuracy: 3)
        XCTAssertTrue(budgetTab(in: app).isSelected)
        attach(app, "overdue-back-budget")
    }

    func testPendingListReturnsToHomeWithoutChangingSelectedCard() {
        let app = launch("r34-home")
        let summary = app.buttons["native.home.summary.used"]
        XCTAssertTrue(summary.waitForExistence(timeout: 10))
        let originalLabel = summary.label
        let pendingTile = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "笔待确认")).firstMatch
        reveal(pendingTile, in: app)
        pendingTile.tap()
        let pending = app.segmentedControls.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "待确认")).firstMatch
        XCTAssertTrue(pending.waitForExistence(timeout: 8), app.debugDescription)
        XCTAssertTrue(pending.isSelected)
        XCTAssertFalse(budgetTab(in: app).isHittable)
        attach(app, "pending-workspace-from-budget")
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.buttons["wallet.budget.detail.close"].waitForExistence(timeout: 5))
        app.buttons["wallet.budget.detail.close"].tap()
        XCTAssertTrue(summary.waitForExistence(timeout: 5))
        XCTAssertEqual(summary.label, originalLabel)
        XCTAssertTrue(budgetTab(in: app).isSelected)
    }

    func testEmptyPeriodSummariesRemainCompactInBothThemes() {
        for appearance in ["light", "dark"] {
            let app = launch("home-overdue", appearance: appearance)
            let used = app.buttons["native.home.summary.used"]
            let calendar = app.buttons["native.home.summary.period"]
            XCTAssertTrue(used.waitForExistence(timeout: 10))
            XCTAssertTrue(calendar.isHittable)
            XCTAssertGreaterThan(used.frame.width, 100)
            XCTAssertLessThan(used.frame.height, 200)
            XCTAssertLessThan(calendar.frame.height, 200)
            XCTAssertEqual(used.frame.midY, calendar.frame.midY, accuracy: 3)
            let records = app.staticTexts["最近记录"]
            XCTAssertTrue(records.exists)
            XCTAssertLessThan(records.frame.minY - max(used.frame.maxY, calendar.frame.maxY), 65)
            XCTAssertTrue(app.buttons["wallet.home.capture"].isHittable)
            attach(app, "compact-budget-\(appearance)")
            app.terminate()
        }
    }

    func testBudgetDetailsReachRecordsAndKeepSelectedCard() {
        let app = launch("r34-home")
        let summary = app.buttons["native.home.summary.used"]
        XCTAssertTrue(summary.waitForExistence(timeout: 10))
        let selected = app.descendants(matching: .any)["wallet.home.card"].firstMatch.label
        summary.tap()
        let records = app.buttons["wallet.workspace.records"]
        reveal(records, in: app)
        records.tap()
        XCTAssertTrue(app.segmentedControls.firstMatch.waitForExistence(timeout: 5))
        XCTAssertFalse(budgetTab(in: app).isHittable)
        attach(app, "budget-detail-records")
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(records.waitForExistence(timeout: 5))
        app.buttons["wallet.budget.detail.close"].tap()
        XCTAssertTrue(summary.waitForExistence(timeout: 5))
        XCTAssertEqual(app.descendants(matching: .any)["wallet.home.card"].firstMatch.label, selected)
        XCTAssertTrue(budgetTab(in: app).isSelected)
    }

    func testLargeEnglishHomeKeepsCaptureAndSummaryActionsReachable() {
        let app = XCUIApplication()
        app.launchArguments = ["-design-preview", "-design-screen", "home-overdue", "-checkline.appearance", "dark",
                               "-design-reduce-motion", "-AppleLanguages", "(en)", "-AppleLocale", "en_US",
                               "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        let capture = app.buttons["wallet.home.capture"]
        XCTAssertTrue(capture.waitForExistence(timeout: 10))
        XCTAssertTrue(capture.isHittable)
        XCTAssertLessThan(capture.frame.maxY, app.frame.maxY - 100)
        capture.tap()
        XCTAssertTrue(app.buttons["wallet.composer.close"].waitForExistence(timeout: 5))
        app.buttons["wallet.composer.close"].tap()
        let used = app.buttons["native.home.summary.used"]
        reveal(used, in: app)
        used.tap()
        XCTAssertTrue(app.buttons["wallet.budget.detail.close"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["wallet.budget.settlement"].exists)
        app.buttons["wallet.budget.detail.close"].tap()
        let calendar = app.buttons["native.home.summary.period"]
        reveal(calendar, in: app)
        XCTAssertGreaterThan(calendar.frame.minY, used.frame.minY)
        attach(app, "large-english-summaries")
        calendar.tap()
        XCTAssertTrue(app.navigationBars["Spending calendar"].waitForExistence(timeout: 5))
        app.navigationBars["Spending calendar"].buttons.firstMatch.tap()
        app.buttons["wallet.budget.detail.close"].tap()
        XCTAssertTrue(capture.isHittable)
    }

    func testVoiceOverCanReadAndOpenOverdueBudget() throws {
        guard #available(iOS 27.0, *) else { throw XCTSkip("VoiceOver automation requires iOS 27.") }
        let app = launch("home-overdue")
        let used = app.buttons["native.home.summary.used"]
        XCTAssertTrue(used.waitForExistence(timeout: 10))
        let voice = XCUIDevice.shared.voiceOverService
        try voice.enable()
        defer { try? voice.disable() }
        var utterances: [String] = []
        for _ in 0..<35 {
            let utterance = try voice.moveForward().utterance
            utterances.append(utterance)
            if utterance.contains("周末旅行") { break }
        }
        XCTAssertTrue(utterances.contains { $0.contains("周末旅行") }, utterances.joined(separator: "\n"))
        used.doubleTap()
        XCTAssertTrue(app.buttons["wallet.budget.settlement"].waitForExistence(timeout: 8))
        var heardStatus = false
        for _ in 0..<35 {
            let utterance = try voice.moveForward().utterance
            utterances.append(utterance)
            if utterance.contains("待结算") || utterance.contains("结算本期") { heardStatus = true; break }
        }
        XCTAssertTrue(heardStatus, utterances.joined(separator: "\n"))
        app.buttons["wallet.budget.detail.close"].doubleTap()
        XCTAssertTrue(used.waitForExistence(timeout: 5))
        let evidence = XCTAttachment(string: utterances.joined(separator: "\n"))
        evidence.name = "overdue-voiceover-speech"; evidence.lifetime = .keepAlways; add(evidence)
        attach(app, "voiceover-overdue-return")
    }

    private func launch(_ screen: String, appearance: String = "light") -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-design-preview", "-design-screen", screen, "-checkline.appearance", appearance,
                               "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()
        return app
    }

    private func budgetTab(in app: XCUIApplication) -> XCUIElement {
        let native = app.tabBars.buttons["预算"].firstMatch
        return native.exists ? native : app.buttons["wallet.tab.budgets"].firstMatch
    }

    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<6 where !element.isHittable {
            let scroll = app.scrollViews.firstMatch
            if scroll.exists { scroll.swipeUp(velocity: .slow) }
        }
        XCTAssertTrue(element.isHittable, app.debugDescription)
    }

    private func attach(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
