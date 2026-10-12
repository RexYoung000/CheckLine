import XCTest

@MainActor
final class CurrentExperienceRepairUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        if #available(iOS 27.0, *) { try XCUIDevice.shared.voiceOverService.disable() }
    }

    func testEstimateOpensPendingDetailAndRefreshesThroughBackNavigation() {
        let app = launch("home-inline")
        let settlement = app.buttons["wallet.budget.settlement"]
        XCTAssertTrue(settlement.waitForExistence(timeout: 10))
        reveal(settlement, in: app); settlement.tap()
        XCTAssertTrue(app.staticTexts["wallet.settlement.estimateOnly"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["wallet.settlement.confirm"].exists)
        XCTAssertFalse(app.buttons["wallet.settlement.acceptData"].exists)
        let pending = app.buttons["wallet.settlement.pending"]
        reveal(pending, in: app); pending.tap()
        let row = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "咖啡")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5)); row.tap()
        let confirm = app.buttons["确认当前归属"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5), app.debugDescription)
        attach(app, "settlement-pending-detail-open")
        confirm.tap()
        XCTAssertTrue(app.staticTexts["已确认"].waitForExistence(timeout: 5))
        app.navigationBars["消费详情"].buttons.firstMatch.tap()
        XCTAssertTrue(app.staticTexts["已全部确认"].waitForExistence(timeout: 5))
        app.buttons["关闭"].firstMatch.tap()
        XCTAssertTrue(pending.waitForExistence(timeout: 5))
        XCTAssertFalse(pending.isEnabled)
        attach(app, "settlement-estimate-updated-after-confirming")
    }

    func testInlineReviewKeepsInputAndCanEditAllFieldsInSameTask() {
        let app = launch("agent-confirm")
        let edit = app.buttons["wallet.agent.editFields"]
        XCTAssertTrue(edit.waitForExistence(timeout: 10), app.debugDescription)
        XCTAssertTrue(app.buttons["继续修改"].exists)
        attach(app, "agent-compact-review")
        edit.tap()
        let amount = app.textFields["输入金额"]
        XCTAssertTrue(amount.waitForExistence(timeout: 5))
        XCTAssertEqual(amount.value as? String, "35")
        amount.tap(); amount.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 8) + "40")
        app.buttons["完成输入"].firstMatch.tap()
        app.buttons["wallet.task.switchMode"].tap()
        XCTAssertTrue(edit.waitForExistence(timeout: 5))
        XCTAssertTrue((edit.value as? String)?.contains("40") == true)
        app.buttons["继续修改"].tap()
        let resume = app.buttons["wallet.task.continue"]
        XCTAssertTrue(resume.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["确认记下"].exists)
        resume.tap()
        XCTAssertTrue(app.buttons["确认记下"].waitForExistence(timeout: 5))
        attach(app, "agent-continue-preserves-corrected-amount")
    }

    func testWishCreationAndRedemptionRestoreInputWithoutRestoringPurchaseConsent() {
        let app = launch("wishes")
        let add = app.buttons["wallet.header.create"]
        XCTAssertTrue(add.waitForExistence(timeout: 10)); add.tap()
        let name = app.textFields["wallet.wishes.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5)); name.tap(); name.typeText("RestoreWishUITest")
        app.buttons["完成输入"].firstMatch.tap()
        app.buttons["关闭"].firstMatch.tap()
        add.tap()
        XCTAssertTrue(name.waitForExistence(timeout: 5)); XCTAssertEqual(name.value as? String, "RestoreWishUITest")
        attach(app, "wish-create-restored")
        app.buttons["wallet.wishes.create.save"].tap()
        let created = app.staticTexts["RestoreWishUITest"]
        XCTAssertTrue(created.waitForExistence(timeout: 5)); created.tap()
        app.buttons["已购买，去兑现"].tap()
        let amount = app.textFields["wallet.wishes.actual"]
        XCTAssertTrue(amount.waitForExistence(timeout: 5)); amount.tap(); amount.typeText("25")
        app.buttons["完成输入"].firstMatch.tap()
        let consent = app.switches["wallet.wishes.purchaseConfirmed"]
        reveal(consent, in: app); consent.tap()
        XCTAssertTrue(app.buttons["wallet.wishes.confirm"].isEnabled)
        app.buttons["关闭"].firstMatch.tap()
        app.buttons["已购买，去兑现"].tap()
        XCTAssertTrue(amount.waitForExistence(timeout: 5)); XCTAssertEqual(amount.value as? String, "25")
        XCTAssertEqual(consent.value as? String, "0")
        XCTAssertFalse(app.buttons["wallet.wishes.confirm"].isEnabled)
        attach(app, "wish-purchase-draft-needs-new-consent")
    }

    func testWalletChangeHasReadOnlyDetailAndAnalysisNamesItsRange() {
        let app = launch("wishes")
        let balance = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "心愿余额")).firstMatch
        XCTAssertTrue(balance.waitForExistence(timeout: 10)); balance.tap()
        let row = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "结余")).firstMatch
        reveal(row, in: app); row.tap()
        XCTAssertTrue(app.navigationBars["余额变动"].waitForExistence(timeout: 5))
        attach(app, "wish-balance-change-detail")
        app.navigationBars["余额变动"].buttons.firstMatch.tap()
        app.buttons["关闭"].firstMatch.tap()
        app.buttons["wallet.tab.insights"].tap()
        XCTAssertTrue(app.staticTexts["wallet.analysis.trendRange"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["本期已用"].exists)
        attach(app, "analysis-period-and-trend-range")
    }

    func testHistoryShowsSelectedPeriodResultAndReturnsToDirectory() {
        let app = launch("history-review")
        let result = app.buttons.matching(NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@", "结余", "750")).firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 10), app.debugDescription)
        result.tap()
        XCTAssertTrue(app.staticTexts["¥750"].waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertFalse(app.staticTexts["还能花"].isHittable, "The selected history page must not present the current card's remaining amount.")
        attach(app, "history-selected-period-result")
        app.navigationBars["日常生活"].buttons.firstMatch.tap()
        XCTAssertTrue(result.waitForExistence(timeout: 5))
        attach(app, "history-directory-restored")
    }

    func testVoiceUnavailableOrDeniedKeepsTypedInputAndManualFallback() {
        let app = launch("agent")
        let input = app.descendants(matching: .any)["wallet.agent.input"].firstMatch
        XCTAssertTrue(input.waitForExistence(timeout: 10))
        input.tap(); input.typeText("午餐 35 元")
        app.buttons["wallet.agent.voice"].tap()
        if app.alerts.firstMatch.waitForExistence(timeout: 2) {
            app.alerts.buttons["开始语音输入"].tap()
        }
        let system = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let deny = system.alerts.buttons.matching(NSPredicate(format: "label == %@ OR label == %@", "不允许", "Don’t Allow")).firstMatch
        if deny.waitForExistence(timeout: 2) { deny.tap() }
        let status = app.staticTexts["wallet.agent.voice.status"]
        XCTAssertTrue(status.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertEqual(input.value as? String, "午餐 35 元")
        XCTAssertFalse(app.buttons["确认记下"].exists)
        attach(app, "voice-native-fallback-preserves-input")
        if app.buttons["wallet.agent.voice.cancel"].exists { app.buttons["wallet.agent.voice.cancel"].tap() }
        app.buttons["wallet.task.switchMode"].tap()
        XCTAssertTrue(app.textFields["输入金额"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.textFields["输入金额"].value as? String, "35")
    }

    func testAttachmentOpensZoomsAndReturnsToRetainedInput() {
        let app = launch("attachment-review")
        let preview = app.buttons["查看图片"]
        XCTAssertTrue(preview.waitForExistence(timeout: 10))
        app.scrollViews.firstMatch.swipeUp()
        reveal(preview, in: app); preview.tap()
        let image = app.images["wallet.attachment.image"]
        XCTAssertTrue(image.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertEqual(image.value as? String, "100%")
        app.buttons["wallet.attachment.zoom"].tap()
        XCTAssertEqual(image.value as? String, "200%")
        attach(app, "attachment-native-zoom")
        app.buttons["wallet.attachment.close"].tap()
        let amount = app.textFields["输入金额"]
        XCTAssertTrue(amount.waitForExistence(timeout: 5))
        XCTAssertEqual(amount.value as? String, "35")
        XCTAssertTrue(preview.exists)
    }

    func testSettingsInlineFactsAndSourceExpansionReturnToSettings() {
        let app = launch("settings")
        let currency = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "钱包基准币")).firstMatch
        XCTAssertTrue(currency.waitForExistence(timeout: 10), app.debugDescription)
        currency.tap()
        XCTAssertTrue(app.staticTexts["结算和心愿购买按此币种核对换算。"].waitForExistence(timeout: 5))
        attach(app, "settings-inline-currency")
        let sources = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "数据来源")).firstMatch
        reveal(sources, in: app); sources.tap()
        XCTAssertTrue(app.staticTexts["wallet.sources.voiceStatus"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["银行短信"].isHittable)
        app.buttons["尚未接通 · 可跳过"].tap()
        XCTAssertTrue(app.staticTexts["银行短信"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.alerts.firstMatch.exists, "Reading source status must not ask for capture permissions.")
        attach(app, "sources-unavailable-expanded")
        app.navigationBars["数据来源与导入"].buttons.firstMatch.tap()
        let privacy = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "隐私与存储")).firstMatch
        reveal(privacy, in: app); privacy.tap()
        XCTAssertTrue(app.staticTexts["本机账本"].waitForExistence(timeout: 5))
        app.navigationBars["隐私与存储"].buttons.firstMatch.tap()
        let about = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "关于")).firstMatch
        reveal(about, in: app); about.tap()
        XCTAssertTrue(app.staticTexts["1.0 (5)"].waitForExistence(timeout: 5))
        attach(app, "about-current-version")
    }

    private func launch(_ screen: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-design-preview", "-design-screen", screen, "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch(); return app
    }
    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<8 where !element.isHittable { app.scrollViews.firstMatch.swipeUp() }
        XCTAssertTrue(element.isHittable, app.debugDescription)
    }
    private func attach(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
}
