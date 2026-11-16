import XCTest

/// Tap the visible field surfaces, not only the accessibility field's exact
/// glyph rectangle. These exercise the same entry points a person uses.
@MainActor final class InputInteractionUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        #if targetEnvironment(simulator)
        if #available(iOS 27.0, *) { try XCUIDevice.shared.voiceOverService.disable() }
        #endif
    }

    func testWishNameSurfaceAndEstimateLabelAcceptTyping() {
        let app = launchPreview("wishes-empty")
        let add = app.buttons["wallet.header.create"]
        XCTAssertTrue(add.waitForExistence(timeout: 8)); add.tap()
        let name = app.textFields["wallet.wishes.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        // The title and blank space visually belong to the same input field.
        app.staticTexts["心愿名称"].tap()
        guard app.keyboards.firstMatch.waitForExistence(timeout: 3) else {
            attach(app, "wish-name-surface-no-keyboard")
            return XCTFail("Tapping the visible name field's label must focus its text input.")
        }
        app.typeText("旅行")
        XCTAssertEqual(name.value as? String, "旅行")
        app.typeText("耳机")
        XCTAssertEqual(name.value as? String, "旅行耳机")
        finishKeyboard(app)
        let estimate = app.textFields["wallet.wishes.estimate"]
        let label = app.staticTexts["预计花费（可选）"]
        if !label.isHittable { app.scrollViews.firstMatch.swipeUp() }
        XCTAssertTrue(label.isHittable); label.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 3))
        app.typeText("49.50")
        XCTAssertEqual(estimate.value as? String, "49.50")
        finishKeyboard(app)
        name.tap(); name.typeText(" Pro")
        XCTAssertEqual(name.value as? String, "旅行耳机 Pro")
        finishKeyboard(app)
        app.buttons["wallet.wishes.create.save"].tap()
        XCTAssertTrue(app.staticTexts["旅行耳机 Pro"].waitForExistence(timeout: 5))
        attach(app, "wish-name-and-amount-saved")
    }

    func testBudgetNameAndLimitLabelsFocusTheirInputs() {
        let app = launchPreview("budget-empty")
        let add = app.buttons["wallet.header.create"]
        XCTAssertTrue(add.waitForExistence(timeout: 8)); add.tap()
        let name = app.textFields["wallet.composer.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        app.staticTexts["预算名称"].tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 3))
        app.typeText("Input surface budget")
        XCTAssertEqual(name.value as? String, "Input surface budget")
        finishKeyboard(app)
        app.staticTexts["额度"].tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 3))
        app.typeText("500")
        XCTAssertEqual(app.textFields["wallet.composer.amount"].value as? String, "500")
        finishKeyboard(app)
        app.buttons["wallet.composer.save"].tap()
        XCTAssertTrue(name.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["wallet.home.card"].firstMatch.staticTexts["Input surface budget"].exists)
    }

    func testWishPersistentInputSurvivesCloseAndRelaunch() throws {
        #if !targetEnvironment(simulator)
        try XCTSkipUnless(ProcessInfo.processInfo.environment["CHECKLINE_ISOLATED_INPUT_QA"] == "1",
                          "Persistent input requires the separate MotionQA app on a physical device.")
        #endif
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()
        let nativeWishes = app.tabBars.buttons["心愿"].firstMatch
        let wishes = nativeWishes.waitForExistence(timeout: 5) ? nativeWishes : app.buttons["wallet.tab.wishes"].firstMatch
        XCTAssertTrue(wishes.waitForExistence(timeout: 10)); wishes.tap()
        let add = app.buttons["wallet.header.create"]
        XCTAssertTrue(add.waitForExistence(timeout: 5)); add.tap()
        let name = app.textFields["wallet.wishes.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        let title = "Input QA " + UUID().uuidString.prefix(6)
        name.tap()
        let existing = name.value as? String ?? ""
        name.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: existing.count) + title)
        XCTAssertEqual(name.value as? String, title)
        finishKeyboard(app)
        app.buttons["关闭"].firstMatch.tap()
        add.tap()
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        XCTAssertEqual(name.value as? String, title)
        app.terminate(); app.launch()
        XCTAssertTrue(wishes.waitForExistence(timeout: 10)); wishes.tap()
        XCTAssertTrue(add.waitForExistence(timeout: 5)); add.tap()
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        XCTAssertEqual(name.value as? String, title)
        name.tap(); name.typeText(" retained")
        finishKeyboard(app)
        app.buttons["wallet.wishes.create.save"].tap()
        XCTAssertTrue(app.staticTexts[title + " retained"].waitForExistence(timeout: 5))
        app.terminate(); app.launch()
        XCTAssertTrue(wishes.waitForExistence(timeout: 10)); wishes.tap()
        XCTAssertTrue(app.staticTexts[title + " retained"].waitForExistence(timeout: 5))
        attach(app, "wish-persistent-input-saved-after-relaunch")
    }

    func testLibrarySearchChangesActualResultsAndCanBeReopened() {
        let app = launchPreview("r34-home")
        XCTAssertTrue(app.buttons["native.holder.down"].waitForExistence(timeout: 8))
        app.buttons["native.holder.down"].tap()
        let search = app.buttons["native.library.search"]
        XCTAssertTrue(search.waitForExistence(timeout: 5)); search.tap()
        let field = app.textFields["native.library.searchField"]
        XCTAssertTrue(field.waitForExistence(timeout: 5)); field.tap()
        field.typeText("NoMatchingBudget")
        XCTAssertEqual(field.value as? String, "NoMatchingBudget")
        XCTAssertEqual(app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@", "native.library.card.")).count, 0)
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 16) + "周末")
        XCTAssertEqual(field.value as? String, "周末")
        let result = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label CONTAINS %@", "native.library.card.", "周末旅行")).firstMatch
        XCTAssertTrue(result.exists)
        XCTAssertFalse(app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label CONTAINS %@", "native.library.card.", "日常生活")).firstMatch.exists)
        search.tap(); search.tap()
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        XCTAssertEqual(field.value as? String, "周末")
        field.tap(); field.typeText("旅行")
        XCTAssertEqual(field.value as? String, "周末旅行")
        result.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.25)).tap()
        XCTAssertTrue(app.descendants(matching: .any)["native.budget.library"].firstMatch.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["wallet.home.card"].firstMatch.staticTexts["周末旅行"].exists)
        attach(app, "library-search-results-follow-input")
    }

    func testHomeRecordKeepsMerchantNoteAndSourceAcrossModeSwitchAndSave() {
        let app = launchPreview("r34-home")
        let record = app.buttons["wallet.home.capture"]
        XCTAssertTrue(record.waitForExistence(timeout: 8)); record.tap()
        let amount = app.textFields["wallet.composer.amount"]
        XCTAssertTrue(amount.waitForExistence(timeout: 5)); amount.tap(); amount.typeText("12.50")
        finishKeyboard(app)
        let merchant = app.textFields["商家"]
        XCTAssertTrue(merchant.isHittable); app.staticTexts["商家"].tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 3))
        app.typeText("Input QA Cafe")
        finishKeyboard(app)
        let extras = app.buttons["备注、文字与附件"]
        reach(extras, app); extras.tap()
        let note = app.textViews["备注，可选"]
        reach(note, app); note.tap(); note.typeText("输入测试备注")
        XCTAssertEqual(note.value as? String, "输入测试备注")
        finishKeyboard(app)
        let source = app.textFields["粘贴原始文字"]
        reach(source, app); app.staticTexts["粘贴原始文字"].tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 3))
        app.typeText("合成票据文字")
        XCTAssertEqual(source.value as? String, "合成票据文字")
        finishKeyboard(app)
        app.buttons["wallet.task.switchMode"].tap()
        XCTAssertTrue(app.buttons["wallet.agent.close"].waitForExistence(timeout: 5))
        app.buttons["wallet.task.switchMode"].tap()
        XCTAssertEqual(amount.value as? String, "12.50")
        XCTAssertEqual(merchant.value as? String, "Input QA Cafe")
        if !note.exists {
            let retainedExtras = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "备注与文字")).firstMatch
            reach(retainedExtras, app); retainedExtras.tap()
        }
        XCTAssertEqual(note.value as? String, "输入测试备注")
        XCTAssertEqual(source.value as? String, "合成票据文字")
        app.buttons["wallet.composer.save"].tap()
        XCTAssertTrue(amount.waitForNonExistence(timeout: 5))
        app.buttons["native.holder.up"].tap()
        let row = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label CONTAINS %@", "native.record.", "Input QA Cafe")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5)); row.tap()
        XCTAssertTrue(app.staticTexts["Input QA Cafe"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["输入测试备注"].exists)
        attach(app, "manual-record-all-text-preserved")
    }

    private func launchPreview(_ screen: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-design-preview", "-design-screen", screen, "-checkline.appearance", "light",
                               "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()
        return app
    }

    private func finishKeyboard(_ app: XCUIApplication) {
        let done = app.buttons["完成输入"].firstMatch
        if done.waitForExistence(timeout: 2), done.isHittable { done.tap() }
    }

    private func reach(_ element: XCUIElement, _ app: XCUIApplication) {
        for _ in 0..<6 where !element.isHittable { app.scrollViews.firstMatch.swipeUp(velocity: .slow) }
        XCTAssertTrue(element.isHittable)
    }

    private func attach(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
}
