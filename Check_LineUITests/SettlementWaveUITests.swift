import XCTest

@MainActor final class SettlementWaveUITests: XCTestCase {
    func testSkipWaveAndReadSavedResult() {
        let app = openResult(reduced: false)
        let skip = app.buttons["native.outcome.skip"]
        XCTAssertTrue(skip.waitForExistence(timeout: 1.5))
        skip.tap()
        XCTAssertFalse(skip.exists)
        checkResult(app)
    }

    func testReducedMotionShowsSavedResultWithoutWave() {
        let app = openResult(reduced: true)
        XCTAssertFalse(app.buttons["native.outcome.skip"].exists)
        checkResult(app)
    }

    func testRecoveryShowsCoveredAmountBeforeWalletTransfer() {
        let app = openResult(reduced: false, screen: "settlement-recovery")
        checkSavedAmounts(in: app, headline: "结余", headlineAmount: "+¥750", walletBalance: "250", impact: [
            ("待恢复差额减少", "-¥500"), ("转入心愿余额", "+¥250")
        ], attachmentName: "settlement-recovery")
    }

    func testOverrunShowsWalletDeductionAndRemainingGap() {
        let app = openResult(reduced: false, screen: "settlement-overrun")
        checkSavedAmounts(in: app, headline: "越线", headlineAmount: "-¥300", walletBalance: "0", impact: [
            ("从心愿钱包扣除", "-¥120"), ("结算后待恢复差额", "¥180")
        ], attachmentName: "settlement-overrun")
    }

    func testBackgroundDuringWaveKeepsOneSavedResultAndUsableReturn() {
        let app = openResult(reduced: false, screen: "settlement-recovery")
        XCTAssertTrue(app.buttons["native.outcome.skip"].waitForExistence(timeout: 1.5),
                      "This test must interrupt an active wave, not an already completed receipt.")
        XCUIDevice.shared.press(.home)
        app.activate()
        let result = app.descendants(matching: .any)["native.outcome.result"].firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["native.outcome.skip"].exists)
        let wallet = result.descendants(matching: .any)["native.outcome.wallet"].firstMatch
        XCTAssertTrue(wallet.label.hasSuffix("¥250"))
        XCTAssertTrue(app.buttons["回到预算"].isHittable)
        app.buttons["回到预算"].tap()
        if app.navigationBars["周末旅行"].buttons["关闭"].exists {
            app.navigationBars["周末旅行"].buttons["关闭"].tap()
        } else if app.buttons["关闭"].firstMatch.exists { app.buttons["关闭"].firstMatch.tap() }
        let nativeWishes = app.tabBars.buttons["心愿"].firstMatch
        let wishes = nativeWishes.exists ? nativeWishes : app.buttons["wallet.tab.wishes"].firstMatch
        XCTAssertTrue(wishes.waitForExistence(timeout: 5)); wishes.tap()
        app.buttons["native.wish.balance"].tap()
        let amount = app.staticTexts["wallet.wishes.balance.detail"]
        XCTAssertTrue(amount.waitForExistence(timeout: 5))
        XCTAssertEqual(amount.value as? String, "¥250", "Resuming the wave must not settle the ledger twice.")
    }

    private func checkSavedAmounts(
        in app: XCUIApplication, headline: String, headlineAmount: String,
        walletBalance: String, impact: [(String, String)], attachmentName: String
    ) {
        let result = app.descendants(matching: .any)["native.outcome.result"].firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["native.outcome.skip"].waitForNonExistence(timeout: 6))
        XCTAssertTrue(result.staticTexts.containing(NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@", headline, headlineAmount)).firstMatch.exists)
        let wallet = result.descendants(matching: .any)["native.outcome.wallet"].firstMatch
        XCTAssertTrue(wallet.exists)
        XCTAssertTrue(wallet.label.hasSuffix("¥" + walletBalance))
        for (label, amount) in impact {
            XCTAssertTrue(result.staticTexts.containing(NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@", label, amount)).firstMatch.exists)
        }
        let image = XCTAttachment(screenshot: app.screenshot())
        image.name = attachmentName
        image.lifetime = .keepAlways
        add(image)
        app.buttons["回到预算"].tap()
        XCTAssertTrue(result.waitForNonExistence(timeout: 5))
    }

    private func openResult(reduced: Bool, screen: String = "settlement-loop") -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-design-preview", "-design-screen", screen, "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        if reduced { app.launchArguments.append("-design-reduce-motion") }
        app.launch()
        app.staticTexts["周末旅行"].firstMatch.tap()
        let settle = app.buttons["wallet.budget.settlement"]
        XCTAssertTrue(settle.waitForExistence(timeout: 8))
        if !settle.isHittable { app.scrollViews.firstMatch.swipeUp(velocity: .slow) }
        settle.tap()
        let accept = app.buttons["wallet.settlement.acceptData"]
        XCTAssertTrue(accept.waitForExistence(timeout: 6))
        accept.tap()
        app.buttons["wallet.settlement.confirm"].tap()
        return app
    }

    private func checkResult(_ app: XCUIApplication) {
        let wallet = app.descendants(matching: .any)["native.outcome.wallet"].firstMatch
        XCTAssertTrue(wallet.exists)
        XCTAssertTrue(wallet.label.contains("750"))
        app.buttons["回到预算"].tap()
        XCTAssertTrue(wallet.waitForNonExistence(timeout: 5))
    }
}
