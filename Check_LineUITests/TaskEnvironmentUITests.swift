import XCTest
import XCUIAutomation

@MainActor
final class TaskEnvironmentUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        if #available(iOS 27.0, *) { try XCUIDevice.shared.voiceOverService.disable() }
    }

    func testVoiceOverCanReadAndSaveManualRecord() throws {
        guard #available(iOS 27.0, *) else { throw XCTSkip("VoiceOver automation requires iOS 27.") }
        let app = launch("record")
        let amount = app.textFields["输入金额"]
        XCTAssertTrue(amount.waitForExistence(timeout: 8))
        let voice = XCUIDevice.shared.voiceOverService
        try voice.enable()
        defer { try? voice.disable() }
        XCTAssertTrue(voice.isEnabled)
        var spoken: [String] = []
        var foundAmount = false
        for _ in 0..<40 {
            let speech = try voice.moveForward().utterance
            spoken.append(speech)
            if speech.contains("输入金额") { foundAmount = true; break }
        }
        XCTAssertTrue(foundAmount, spoken.joined(separator: "\n"))
        amount.doubleTap()
        amount.typeText("8")
        XCTAssertEqual(amount.value as? String, "8")
        var foundSave = false
        for _ in 0..<80 {
            let speech = try voice.moveForward().utterance
            spoken.append(speech)
            if speech.contains("记一笔") && speech.contains("按钮") { foundSave = true; break }
        }
        let evidence = XCTAttachment(string: spoken.joined(separator: "\n")); evidence.name = "voiceover-manual-task-speech"; evidence.lifetime = .keepAlways; add(evidence)
        XCTAssertTrue(foundSave)
        app.buttons["wallet.composer.save"].doubleTap()
        XCTAssertTrue(amount.waitForNonExistence(timeout: 8))
        attach(app, "voiceover-record-saved")
    }

    func testSystemReduceMotionIsReflectedInAppAndTaskStillWorks() throws {
        let settings = XCUIApplication(bundleIdentifier: "com.apple.Preferences")
        settings.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        settings.launch()
        let accessibility = settings.buttons["com.apple.settings.accessibility"]
        for _ in 0..<5 { if accessibility.isHittable { break }; settings.swipeUp() }
        XCTAssertTrue(accessibility.waitForExistence(timeout: 8), settings.debugDescription)
        accessibility.tap()
        let motion = settings.buttons["Motion"]
        XCTAssertTrue(motion.waitForExistence(timeout: 8), settings.debugDescription)
        motion.tap()
        let toggle = settings.switches["Reduce Motion"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5), settings.debugDescription)
        let wasEnabled = toggle.value as? String == "1"
        if !wasEnabled { toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap() }
        XCTAssertEqual(toggle.value as? String, "1", settings.debugDescription)
        defer {
            if !wasEnabled {
                settings.activate()
                if toggle.exists { toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap() }
            }
        }
        let app = launch("settings")
        XCTAssertTrue(app.staticTexts["静态显示"].waitForExistence(timeout: 8), app.debugDescription)
        attach(app, "system-reduce-motion-setting")
        app.terminate()
        let task = launch("record")
        task.textFields["输入金额"].tap(); task.textFields["输入金额"].typeText("8")
        task.buttons["wallet.task.switchMode"].tap()
        task.buttons["wallet.task.switchMode"].tap()
        XCTAssertEqual(task.textFields["输入金额"].value as? String, "8")
        task.buttons["wallet.composer.save"].tap()
        XCTAssertTrue(task.textFields["输入金额"].waitForNonExistence(timeout: 5))
        attach(task, "system-reduce-motion-task-saved")
    }

    func testPersistentDraftSurvivesAppRelaunchWithoutSubmittingLedger() {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()
        app.buttons["wallet.functions"].tap(); app.buttons["创建预算卡"].tap()
        let name = app.textFields["输入预算名称"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap(); name.typeText("草稿恢复样例")
        let amount = app.textFields["额度"]
        amount.tap(); amount.typeText("123.45")
        app.buttons["wallet.composer.close"].tap()
        app.terminate(); app.launch()
        app.buttons["wallet.functions"].tap(); app.buttons["创建预算卡"].tap()
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        XCTAssertEqual(name.value as? String, "草稿恢复样例")
        XCTAssertEqual(amount.value as? String, "123.45")
        attach(app, "persistent-task-relaunch")
        app.buttons["任务选项"].tap(); app.buttons["放弃这份草稿"].tap(); app.alerts["清除未保存的内容？"].buttons["放弃草稿"].tap()
    }

    func testEnglishTaskKeepsItsFieldsAndSaveReachableWithKeyboard() {
        let app = XCUIApplication()
        app.launchArguments = ["-design-preview", "-design-screen", "record", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        let amount = app.textFields["Amount"]
        XCTAssertTrue(amount.waitForExistence(timeout: 8), app.debugDescription)
        amount.tap(); amount.typeText("8")
        attach(app, "english-task-keyboard")
        XCTAssertTrue(app.buttons["wallet.composer.save"].isEnabled)
        XCTAssertTrue(app.buttons["wallet.composer.save"].isHittable)
        app.buttons["wallet.task.switchMode"].tap()
        XCTAssertTrue(app.buttons["wallet.agent.close"].waitForExistence(timeout: 5))
        app.buttons["wallet.task.switchMode"].tap()
        XCTAssertEqual(amount.value as? String, "8")
        app.buttons["wallet.composer.save"].tap()
        XCTAssertTrue(amount.waitForNonExistence(timeout: 5))
        attach(app, "english-task-saved")
    }

    func testLargeTypeAgentKeepsVoiceAndManualSaveReachable() {
        let app = XCUIApplication()
        app.launchArguments = ["-design-preview", "-design-screen", "agent", "-AppleLanguages", "(en)", "-AppleLocale", "en_US", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        let input = app.descendants(matching: .any).matching(identifier: "wallet.agent.input").firstMatch
        XCTAssertTrue(input.waitForExistence(timeout: 8))
        input.tap(); input.typeText("lunch 35 CNY")
        XCTAssertTrue(app.buttons["wallet.agent.send"].isHittable)
        XCTAssertTrue(app.buttons["wallet.agent.voice"].isHittable)
        attach(app, "large-type-agent-keyboard")
        app.buttons["wallet.agent.voice"].tap()
        XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 5))
        app.alerts.buttons["Cancel"].tap()
        app.buttons["wallet.task.switchMode"].tap()
        let amount = app.textFields["Amount"]
        XCTAssertTrue(amount.waitForExistence(timeout: 5))
        XCTAssertEqual(amount.value as? String, "35")
        XCTAssertTrue(app.buttons["wallet.composer.save"].isHittable)
        app.buttons["wallet.composer.save"].tap()
        XCTAssertTrue(amount.waitForNonExistence(timeout: 5))
        attach(app, "large-type-agent-manual-saved")
    }

    private func launch(_ screen: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-design-preview", "-design-screen", screen, "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch(); return app
    }
    private func attach(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
}
