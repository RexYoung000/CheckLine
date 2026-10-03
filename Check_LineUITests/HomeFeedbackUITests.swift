import XCTest
import XCUIAutomation

@MainActor
final class HomeFeedbackUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        if #available(iOS 27.0, *) { try XCUIDevice.shared.voiceOverService.disable() }
    }

    func testOverdueTaskOpensFullWorkspaceAndReturnsToHome() {
        let app = launch("home-overdue")
        let used = app.buttons["wallet.home.summary.used"]
        XCTAssertTrue(used.waitForExistence(timeout: 10))
        let originalFrame = used.frame
        app.buttons["wallet.attention"].tap()
        let task = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "wallet.attention.budget.")).firstMatch
        XCTAssertTrue(task.waitForExistence(timeout: 5))
        XCTAssertTrue(task.label.contains("已到期"), task.label)
        task.tap()

        let records = app.buttons["wallet.workspace.records"]
        XCTAssertTrue(records.waitForExistence(timeout: 8), app.debugDescription)
        XCTAssertFalse(app.navigationBars["待处理事项"].exists)
        XCTAssertFalse(app.buttons["wallet.attention"].isHittable)
        XCTAssertFalse(app.tabBars.firstMatch.isHittable)
        let page = app.scrollViews["wallet.workspace.page"]
        XCTAssertGreaterThan(page.frame.height, app.frame.height * 0.8, "The budget must open as a full page, not another sheet over Home.")
        XCTAssertTrue(app.staticTexts["待结算"].exists)
        XCTAssertTrue(app.buttons["wallet.budget.settlement"].exists)
        attach(app, "overdue-full-workspace")

        records.tap()
        XCTAssertTrue(app.segmentedControls.firstMatch.waitForExistence(timeout: 5))
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(records.waitForExistence(timeout: 5))
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(used.waitForExistence(timeout: 5))
        XCTAssertTrue(used.isHittable)
        XCTAssertEqual(used.frame.minY, originalFrame.minY, accuracy: 3)
        XCTAssertTrue(app.buttons["wallet.tab.home"].exists)
        attach(app, "overdue-back-home")
    }

    func testPendingTaskReturnsToHomeWithoutChangingSelectedCard() {
        let app = launch("home")
        let originalSummary = app.buttons["wallet.home.summary.used"]
        XCTAssertTrue(originalSummary.waitForExistence(timeout: 10))
        let originalLabel = originalSummary.label
        XCTAssertTrue(app.buttons["wallet.attention"].waitForExistence(timeout: 10))
        app.buttons["wallet.attention"].tap()
        let task = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "wallet.attention.budget.")).firstMatch
        XCTAssertTrue(task.waitForExistence(timeout: 5))
        task.tap()
        let pending = app.segmentedControls.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "待确认")).firstMatch
        XCTAssertTrue(pending.waitForExistence(timeout: 8), app.debugDescription)
        XCTAssertTrue(pending.isSelected)
        XCTAssertFalse(app.navigationBars["待处理事项"].exists)
        XCTAssertFalse(app.tabBars.firstMatch.isHittable)
        attach(app, "pending-full-workspace-from-home")
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(originalSummary.waitForExistence(timeout: 5))
        XCTAssertEqual(originalSummary.label, originalLabel)
        XCTAssertTrue(app.buttons["wallet.tab.home"].exists)
    }

    func testEmptyPeriodSummariesRemainCompactInBothThemes() {
        for appearance in ["light", "dark"] {
            let app = launch("home-overdue", appearance: appearance)
            let used = app.buttons["wallet.home.summary.used"]
            let calendar = app.buttons["wallet.home.summary.calendar"]
            XCTAssertTrue(used.waitForExistence(timeout: 10))
            XCTAssertTrue(calendar.isHittable)
            XCTAssertGreaterThan(used.frame.width, 100)
            XCTAssertLessThan(used.frame.height, 200)
            XCTAssertLessThan(calendar.frame.height, 200)
            XCTAssertEqual(used.frame.minY, calendar.frame.minY, accuracy: 3)
            let records = app.staticTexts["wallet.home.records.title"]
            XCTAssertTrue(records.exists)
            XCTAssertLessThan(records.frame.minY - max(used.frame.maxY, calendar.frame.maxY), 65)
            XCTAssertTrue(app.buttons["记一笔"].firstMatch.isHittable, "The front pocket must not cover the card's add action.")
            attach(app, "compact-home-\(appearance)")
            app.terminate()
        }
    }

    func testAnalysisRecordEntryUsesFullPageAndKeepsSelectedCard() {
        let app = launch("insights")
        let picker = app.buttons["wallet.analysis.cardPicker"]
        XCTAssertTrue(picker.waitForExistence(timeout: 10))
        picker.tap()
        app.buttons["周末旅行"].firstMatch.tap()
        let selectedLabel = picker.label
        app.buttons["wallet.analysis.records"].tap()
        XCTAssertTrue(app.segmentedControls.firstMatch.waitForExistence(timeout: 5))
        XCTAssertFalse(app.tabBars.firstMatch.isHittable)
        XCTAssertGreaterThan(app.scrollViews["wallet.workspace.page"].frame.height, app.frame.height * 0.8)
        attach(app, "analysis-full-records")
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        XCTAssertEqual(picker.label, selectedLabel)
        XCTAssertTrue(app.buttons["wallet.tab.insights"].exists)
        attach(app, "analysis-keeps-selected-card")
    }

    func testLargeEnglishHomeKeepsCaptureAndSummaryActionsReachable() {
        let app = XCUIApplication()
        app.launchArguments = ["-design-preview", "-design-screen", "home-overdue", "-checkline.appearance", "dark",
                               "-design-reduce-motion", "-AppleLanguages", "(en)", "-AppleLocale", "en_US",
                               "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        let capture = app.buttons["wallet.home.capture"]
        XCTAssertTrue(capture.waitForExistence(timeout: 10))
        scrollToReach(capture, in: app)
        XCTAssertTrue(capture.isHittable)
        XCTAssertLessThan(capture.frame.maxY, app.frame.maxY - 100, "Scroll the control fully above the floating navigation before tapping.")
        capture.tap()
        XCTAssertTrue(app.buttons["wallet.composer.close"].waitForExistence(timeout: 5))
        app.buttons["wallet.composer.close"].tap()
        let used = app.buttons["wallet.home.summary.used"]
        scrollToReach(used, in: app)
        XCTAssertTrue(used.isHittable)
        used.tap()
        XCTAssertTrue(app.buttons["Close"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Spent this period"].exists, app.debugDescription)
        app.buttons["Close"].tap()
        let calendar = app.buttons["wallet.home.summary.calendar"]
        scrollToReach(calendar, in: app)
        XCTAssertTrue(calendar.isHittable)
        XCTAssertGreaterThan(calendar.frame.minY, used.frame.minY)
        attach(app, "large-english-summaries")
        calendar.tap()
        XCTAssertTrue(app.buttons["Close"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Spending calendar"].exists)
        app.buttons["Close"].tap()
        XCTAssertTrue(capture.exists)
    }

    func testVoiceOverCanReadAndOpenOverdueTask() throws {
        guard #available(iOS 27.0, *) else { throw XCTSkip("VoiceOver automation requires iOS 27.") }
        let app = launch("attention-overdue")
        let task = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "wallet.attention.budget.")).firstMatch
        XCTAssertTrue(task.waitForExistence(timeout: 10))
        let voice = XCUIDevice.shared.voiceOverService
        try voice.enable()
        defer { try? voice.disable() }
        var utterances: [String] = []
        var foundTask = false
        for _ in 0..<30 {
            let utterance = try voice.moveForward().utterance
            utterances.append(utterance)
            if utterance.contains("周末旅行") && utterance.contains("已到期") { foundTask = true; break }
        }
        XCTAssertTrue(foundTask, utterances.joined(separator: "\n"))
        task.doubleTap()
        XCTAssertTrue(app.buttons["wallet.workspace.records"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.navigationBars["待处理事项"].exists)
        app.navigationBars.buttons.firstMatch.doubleTap()
        XCTAssertTrue(app.buttons["wallet.home.summary.used"].waitForExistence(timeout: 5))
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

    private func scrollToReach(_ element: XCUIElement, in app: XCUIApplication) {
        // Short, reversible drags prevent a full-screen fling from skipping the control.
        let safeTop = app.frame.minY + 160
        let safeBottom = app.frame.maxY - 110
        for _ in 0..<15 {
            let frame = element.frame
            if element.isHittable && frame.midY > safeTop && frame.maxY < safeBottom { return }
            let upward = frame.maxY > safeBottom
            let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: upward ? 0.62 : 0.42))
            let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: upward ? 0.42 : 0.62))
            start.press(forDuration: 0.01, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.05)
        }
    }

    private func attach(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
