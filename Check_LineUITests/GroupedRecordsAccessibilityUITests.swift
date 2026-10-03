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
        app.launchArguments = ["-design-preview", "-design-screen", "home-inline", "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()
        let records = app.buttons["wallet.workspace.records"]
        XCTAssertTrue(records.waitForExistence(timeout: 8))
        records.tap()
        let pending = app.segmentedControls.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "待确认")).firstMatch
        XCTAssertTrue(pending.waitForExistence(timeout: 5))
        pending.tap()
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
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "咖啡")).firstMatch.doubleTap()
        XCTAssertTrue(app.staticTexts["记录来源"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["确认当前归属"].exists)
    }
}
