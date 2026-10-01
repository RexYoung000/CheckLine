import XCTest
import XCUIAutomation

@MainActor
final class SettlementReceiptStudyUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        if #available(iOS 27.0, *) { try XCUIDevice.shared.voiceOverService.disable() }
    }

    func testReplayCanBeInterruptedAndScenarioChangedWithoutLosingResult() {
        let app = launch()
        XCTAssertTrue(app.buttons["receipt.options"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["receipt.amount"].isHittable)
        for _ in 0..<3 { option("重播出纸", in: app) }
        option("直接看结果", in: app)
        XCTAssertEqual(app.staticTexts["receipt.status"].label, "已出纸")
        XCTAssertTrue(app.buttons["receipt.details"].isHittable)
        XCTAssertTrue(app.staticTexts["receipt.amount"].isHittable)
        XCTAssertTrue(app.staticTexts["receipt.amount"].label.contains("532"))
        attach(app, "receipt-surplus-interrupted")

        option("越线示例", in: app)
        option("直接看结果", in: app)
        XCTAssertTrue(app.staticTexts["receipt.amount"].label.contains("240"))
        attach(app, "receipt-overrun")
        option("重播出纸", in: app)
        app.buttons["receipt.close"].tap()
        XCTAssertTrue(app.buttons["receipt.open"].waitForExistence(timeout: 5))
        app.buttons["receipt.open"].tap()
        XCTAssertEqual(app.staticTexts["receipt.status"].label, "已出纸", "Reopening this result must not print automatically.")
        XCTAssertTrue(app.staticTexts["receipt.amount"].label.contains("240"))
    }

    func testReducedMotionImmediatelyShowsFullResultAndKeepsScenarioUsable() {
        let app = launch(reduced: true)
        XCTAssertTrue(app.descendants(matching: .any)["receipt.static"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["receipt.amount"].isHittable)
        app.buttons["receipt.options"].tap()
        XCTAssertFalse(app.buttons["重播出纸"].exists)
        app.buttons["越线示例"].tap()
        XCTAssertTrue(app.staticTexts["receipt.amount"].label.contains("240"))
        attach(app, "receipt-reduced-motion")
    }

    func testLargeTextCanScrollToTheEndOfReceiptWithControlsReachable() {
        let app = launch(reduced: true)
        XCTAssertTrue(app.staticTexts["receipt.amount"].waitForExistence(timeout: 8))
        let note = app.staticTexts["心愿钱包是账本结果，不是真实资金。"]
        for _ in 0..<6 {
            if note.isHittable { break }
            app.scrollViews.firstMatch.swipeUp()
        }
        XCTAssertTrue(note.isHittable, app.debugDescription)
        XCTAssertTrue(app.buttons["receipt.close"].isHittable)
        XCTAssertTrue(app.buttons["receipt.returnBudget"].isHittable)
        XCTAssertTrue(app.buttons["receipt.options"].isHittable)
        attach(app, "receipt-large-text-scrolled")
    }

    func testDetailsAndCompletionDestinationsKeepTheSameResult() {
        let app = launch(reduced: true)
        XCTAssertTrue(app.buttons["receipt.details"].waitForExistence(timeout: 8))
        let limit = app.descendants(matching: .any)["receipt.limitRow"]
        XCTAssertFalse(limit.exists)
        app.buttons["receipt.details"].tap()
        XCTAssertTrue(limit.exists)
        XCTAssertTrue(limit.label.contains("3,000"), limit.debugDescription)
        attach(app, "receipt-details-expanded")

        app.buttons["receipt.viewWallet"].tap()
        let wallet = app.staticTexts["receipt.walletPreviewAmount"]
        XCTAssertTrue(wallet.waitForExistence(timeout: 5))
        XCTAssertTrue(wallet.label.contains("1,092"))
        attach(app, "receipt-wallet-destination")
        app.buttons["receipt.backFromWallet"].tap()
        XCTAssertEqual(app.staticTexts["receipt.status"].label, "已出纸")
        app.buttons["receipt.returnBudget"].tap()
        XCTAssertTrue(app.buttons["receipt.open"].waitForExistence(timeout: 5))
        app.buttons["receipt.open"].tap()
        XCTAssertEqual(app.staticTexts["receipt.status"].label, "已出纸")
        XCTAssertTrue(limit.exists, "Reopening must preserve the chosen detail state.")
    }

    private func option(_ title: String, in app: XCUIApplication) {
        app.buttons["receipt.options"].tap()
        let action = app.buttons[title]
        XCTAssertTrue(action.waitForExistence(timeout: 3), app.debugDescription)
        action.tap()
    }

    func testVoiceOverReadsTheResultAndOpensItsWalletDestination() throws {
        guard #available(iOS 27.0, *) else { throw XCTSkip("Native VoiceOver automation requires iOS 27.") }
        let app = launch()
        let voice = XCUIDevice.shared.voiceOverService
        try voice.enable()
        defer { try? voice.disable() }
        XCTAssertTrue(app.descendants(matching: .any)["receipt.static"].waitForExistence(timeout: 5))
        var spoken: [String] = []
        var readResult = false
        var foundWallet = false
        for _ in 0..<60 {
            let utterance = try voice.moveForward().utterance
            spoken.append(utterance)
            if utterance.contains("532") || utterance.contains("五百三十二") { readResult = true }
            if utterance.contains("查看心愿钱包") { foundWallet = true; break }
        }
        XCTAssertTrue(readResult, spoken.joined(separator: "\n"))
        XCTAssertTrue(foundWallet, spoken.joined(separator: "\n"))
        app.buttons["receipt.viewWallet"].doubleTap()
        XCTAssertTrue(app.staticTexts["receipt.walletPreviewAmount"].waitForExistence(timeout: 5))
        var readWallet = false
        var foundReturn = false
        for _ in 0..<30 {
            let utterance = try voice.moveForward().utterance
            spoken.append(utterance)
            if utterance.contains("1,092") || utterance.contains("1092") || utterance.contains("一千零九十二") { readWallet = true }
            if utterance.contains("返回结算小票") { foundReturn = true; break }
        }
        let evidence = XCTAttachment(string: spoken.joined(separator: "\n"))
        evidence.name = "receipt-voiceover-spoken-example"; evidence.lifetime = .keepAlways; add(evidence)
        XCTAssertTrue(readWallet, spoken.joined(separator: "\n"))
        XCTAssertTrue(foundReturn, spoken.joined(separator: "\n"))
        app.buttons["receipt.backFromWallet"].doubleTap()
        XCTAssertTrue(app.staticTexts["receipt.amount"].waitForExistence(timeout: 5))
        attach(app, "receipt-voiceover-returned")
    }

    private func launch(reduced: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-design-preview", "-design-screen", "settlement-receipt", "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        if reduced { app.launchArguments.append("-design-reduce-motion") }
        app.launch()
        return app
    }

    private func attach(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
}
