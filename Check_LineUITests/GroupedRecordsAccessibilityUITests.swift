import XCTest
import XCUIAutomation

@MainActor
final class GroupedRecordsAccessibilityUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    func testVoiceOverReadsFullDateAndPendingStateBeforeOpeningRecord() throws {
        guard #available(iOS 27.0, *) else { throw XCTSkip("Native VoiceOver automation requires iOS 27.") }
        let voice = XCUIDevice.shared.voiceOverService
        try voice.disable()
        let app = XCUIApplication()
        app.launchArguments = ["-design-preview", "-design-screen", "r34-home", "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()
        let summary = app.buttons["native.home.summary.used"]
        XCTAssertTrue(summary.waitForExistence(timeout: 10))
        XCTAssertTrue(summary.isHittable)
        summary.tap()
        let details = app.scrollViews["wallet.workspace.page"].firstMatch
        XCTAssertTrue(details.waitForExistence(timeout: 5), app.debugDescription)
        let records = details.buttons["wallet.workspace.records"]
        for _ in 0..<6 where !records.isHittable { details.swipeUp(velocity: .slow) }
        XCTAssertTrue(records.isHittable, app.debugDescription)
        records.tap()
        let pending = app.segmentedControls.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "待确认")).firstMatch
        XCTAssertTrue(pending.waitForExistence(timeout: 5))
        pending.tap()
        XCTAssertTrue(pending.isSelected)
        let coffee = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "咖啡")).firstMatch
        XCTAssertTrue(coffee.waitForExistence(timeout: 5), app.debugDescription)
        try voice.enable()
        defer { try? voice.disable() }
        let year = String(Calendar.current.component(.year, from: Date()))
        var spoken: [String] = []
        var foundRecord = false
        for _ in 0..<50 {
            let utterance = try voice.moveForward().utterance
            spoken.append(utterance)
            if utterance.contains("咖啡") {
                XCTAssertTrue(utterance.contains("待确认"), utterance)
                XCTAssertTrue(utterance.contains(year), utterance)
                foundRecord = true
                break
            }
        }
        let speech = XCTAttachment(string: spoken.joined(separator: "\n"))
        speech.name = "grouped-record-voiceover-speech"
        speech.lifetime = .keepAlways
        add(speech)
        XCTAssertTrue(foundRecord, spoken.joined(separator: "\n"))
        coffee.doubleTap()
        XCTAssertTrue(app.staticTexts["记录来源"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["确认当前归属"].exists)
        app.navigationBars["消费详情"].buttons.firstMatch.doubleTap()
        XCTAssertTrue(pending.waitForExistence(timeout: 5))
        XCTAssertTrue(pending.isSelected)
        XCTAssertTrue(coffee.isHittable)
    }
}
