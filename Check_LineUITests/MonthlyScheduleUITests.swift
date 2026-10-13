import XCTest

@MainActor
final class MonthlyScheduleUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        if #available(iOS 27.0, *) { try XCUIDevice.shared.voiceOverService.disable() }
    }

    func testMonthlyWindowSurvivesModesAndCanBeCreated() {
        let app = launch()
        enterBudget(app, name: "Window card")
        let kind = app.segmentedControls["wallet.composer.monthlyKind"]
        reach(kind, in: app); kind.buttons["指定区间"].tap()
        chooseDay(5, picker: "wallet.composer.monthlyStart", in: app)
        chooseDay(20, picker: "wallet.composer.monthlyEnd", in: app)
        XCTAssertTrue(app.staticTexts["每月 5～20 日"].exists)
        XCTAssertTrue(app.staticTexts["区间外消费不计入这张卡"].exists)
        attach(app, "monthly-window-selected")

        let cycle = app.segmentedControls["wallet.composer.cycle"]
        reach(cycle, in: app); cycle.buttons["一次性"].tap(); cycle.buttons["每月循环"].tap()
        XCTAssertTrue(kind.buttons["指定区间"].isSelected)
        XCTAssertEqual(app.buttons["wallet.composer.monthlyStart"].value as? String, "5 日")
        XCTAssertEqual(app.buttons["wallet.composer.monthlyEnd"].value as? String, "20 日")
        app.buttons["wallet.task.switchMode"].tap()
        let rule = app.staticTexts["每月 5～20 日"]
        XCTAssertTrue(rule.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Window card"].exists)
        let input = app.descendants(matching: .any).matching(identifier: "wallet.agent.input").firstMatch
        input.tap(); input.typeText("改成500元")
        app.buttons["wallet.agent.send"].tap()
        dismissKeyboard(app, english: false)
        XCTAssertTrue(app.staticTexts["Window card"].exists)
        attach(app, "monthly-window-agent-review")
        app.buttons["wallet.task.switchMode"].tap()
        XCTAssertEqual(app.textFields["wallet.composer.name"].value as? String, "Window card")
        XCTAssertEqual(app.textFields["额度"].value as? String, "500")
        XCTAssertEqual(app.buttons["wallet.composer.monthlyStart"].value as? String, "5 日")
        XCTAssertEqual(app.buttons["wallet.composer.monthlyEnd"].value as? String, "20 日")
        app.buttons["wallet.composer.save"].tap()
        let saved = app.buttons["Window card"].firstMatch
        XCTAssertTrue(saved.waitForExistence(timeout: 5))
        saved.tap()
        let info = app.buttons["卡片信息与管理"].firstMatch
        // NavigationLink is exposed as a button with the section title.
        reach(info, in: app); info.tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "每月 5～20 日")).firstMatch.waitForExistence(timeout: 5))
        attach(app, "monthly-window-budget-information")
    }

    func testCrossMonthWindowShowsNextMonthAndUpcomingState() {
        let app = launch()
        enterBudget(app, name: "Cross month card")
        let kind = app.segmentedControls["wallet.composer.monthlyKind"]
        reach(kind, in: app); kind.buttons["指定区间"].tap()
        chooseDay(20, picker: "wallet.composer.monthlyStart", in: app)
        chooseDay(5, picker: "wallet.composer.monthlyEnd", in: app)
        XCTAssertTrue(app.staticTexts["每月 20 日～次月 5 日"].exists)
        XCTAssertTrue(app.staticTexts["结束日（次月）"].exists)
        let dates = app.staticTexts["wallet.composer.periodDates"]
        XCTAssertTrue(dates.exists && !dates.label.isEmpty)
        attach(app, "monthly-cross-month-preview")
        app.buttons["wallet.composer.save"].tap()
        XCTAssertTrue(app.buttons["Cross month card"].firstMatch.waitForExistence(timeout: 5))
        attach(app, "monthly-cross-month-created")
    }

    func testChosenFullCycleDaySurvivesClosingAndCanSave() {
        let app = launch()
        enterBudget(app, name: "Full cycle card")
        chooseDay(31, picker: "wallet.composer.monthlyStart", in: app)
        XCTAssertTrue(app.staticTexts["短月按月底调整，临界日只计入新一期"].exists)
        attach(app, "monthly-full-cycle-31")
        app.buttons["wallet.composer.close"].tap()
        app.buttons["wallet.empty.card"].tap()
        let start = app.buttons["wallet.composer.monthlyStart"]
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        XCTAssertEqual(start.value as? String, "31 日")
        XCTAssertEqual(app.textFields["wallet.composer.name"].value as? String, "Full cycle card")
        app.buttons["wallet.composer.save"].tap()
        XCTAssertTrue(app.buttons["Full cycle card"].firstMatch.waitForExistence(timeout: 5))
    }

    func testEnglishDarkLargeTextCanChooseRangeAndSave() {
        let app = launch(english: true, largeText: true)
        enterBudget(app, name: "Monthly range", english: true)
        let kind = app.buttons["wallet.composer.monthlyKind"]
        reach(kind, in: app); kind.tap()
        app.buttons["Date range"].tap()
        chooseDay(5, picker: "wallet.composer.monthlyStart", in: app, english: true)
        chooseDay(20, picker: "wallet.composer.monthlyEnd", in: app, english: true)
        XCTAssertTrue(app.staticTexts["Days 5–20 each month"].exists)
        let save = app.buttons["wallet.composer.save"]
        XCTAssertTrue(save.isHittable && save.isEnabled)
        attach(app, "monthly-range-english-dark-largest-text")
        save.tap()
        XCTAssertTrue(app.buttons["Monthly range"].firstMatch.waitForExistence(timeout: 5))
    }

    func testMonthlyDraftSurvivesAppRelaunchWithoutCreatingBudget() {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()
        app.buttons["wallet.functions"].tap(); app.buttons["创建预算卡"].tap()
        let name = app.textFields["wallet.composer.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5)); name.tap(); name.typeText("月度日期恢复样例")
        let amount = app.textFields["额度"]; amount.tap(); amount.typeText("600")
        let done = app.buttons["完成输入"].firstMatch
        if done.waitForExistence(timeout: 2), done.isHittable { done.tap() }
        let kind = app.segmentedControls["wallet.composer.monthlyKind"]
        reach(kind, in: app); kind.buttons["指定区间"].tap()
        chooseDay(20, picker: "wallet.composer.monthlyStart", in: app)
        chooseDay(5, picker: "wallet.composer.monthlyEnd", in: app)
        app.buttons["wallet.composer.close"].tap()
        app.terminate(); app.launch()
        app.buttons["wallet.functions"].tap(); app.buttons["创建预算卡"].tap()
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        XCTAssertEqual(name.value as? String, "月度日期恢复样例")
        XCTAssertEqual(app.buttons["wallet.composer.monthlyStart"].value as? String, "20 日")
        XCTAssertEqual(app.buttons["wallet.composer.monthlyEnd"].value as? String, "5 日")
        XCTAssertTrue(kind.buttons["指定区间"].isSelected)
        attach(app, "monthly-range-after-process-relaunch")
        app.buttons["wallet.task.options"].tap(); app.buttons["放弃这份草稿"].tap()
        app.alerts["清除未保存的内容？"].buttons["放弃草稿"].tap()
    }

    private func launch(english: Bool = false, largeText: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-design-preview", "-design-screen", "budget-empty", "-checkline.appearance", english ? "dark" : "light",
                               "-AppleLanguages", english ? "(en)" : "(zh-Hans)", "-AppleLocale", english ? "en_US" : "zh_CN"]
        if largeText { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] }
        app.launch(); return app
    }
    private func enterBudget(_ app: XCUIApplication, name: String, english: Bool = false) {
        let create = app.buttons["wallet.empty.card"]
        XCTAssertTrue(create.waitForExistence(timeout: 10)); create.tap()
        let field = app.textFields["wallet.composer.name"]
        XCTAssertTrue(field.waitForExistence(timeout: 5)); field.tap(); field.typeText(name)
        dismissKeyboard(app, english: english)
        let amount = app.textFields[english ? "Amount" : "额度"]
        reach(amount, in: app)
        amount.tap()
        amount.typeText("600")
        dismissKeyboard(app, english: english)
    }
    private func dismissKeyboard(_ app: XCUIApplication, english: Bool) {
        let done = app.buttons[english ? "Done" : "完成输入"].firstMatch
        if done.waitForExistence(timeout: 2), done.isHittable { done.tap() }
    }
    private func chooseDay(_ day: Int, picker id: String, in app: XCUIApplication, english: Bool = false) {
        let picker = app.buttons[id]; reach(picker, in: app)
        let oldDay = (picker.value as? String)?.components(separatedBy: CharacterSet.decimalDigits.inverted).compactMap(Int.init).first ?? 1
        picker.tap()
        let title = english ? "Day \(day)" : "\(day) 日"
        let choice = app.buttons.matching(identifier: title).firstMatch
        let menu = app.collectionViews.firstMatch
        XCTAssertTrue(menu.waitForExistence(timeout: 5), app.debugDescription)
        for _ in 0..<8 where !choice.exists || !choice.isHittable {
            if day < oldDay { menu.swipeDown() } else { menu.swipeUp() }
        }
        XCTAssertTrue(choice.exists && choice.isHittable, app.debugDescription); choice.tap()
        XCTAssertEqual(picker.value as? String, title)
    }
    private func reach(_ element: XCUIElement, in app: XCUIApplication) {
        XCTAssertTrue(element.waitForExistence(timeout: 5), app.debugDescription)
        let ownedForm = app.scrollViews.containing(.textField, identifier: "wallet.composer.name").firstMatch
        let form = ownedForm.exists ? ownedForm : app.scrollViews.firstMatch
        for _ in 0..<12 {
            let top = form.frame.minY + 18
            let save = app.buttons["wallet.composer.save"]
            let validation = app.staticTexts["wallet.composer.validation"]
            let footerTop = min(save.exists ? save.frame.minY : form.frame.maxY,
                                validation.exists ? validation.frame.minY : form.frame.maxY)
            let bottom = min(form.frame.maxY, footerTop) - 18
            if element.frame.minY >= top && element.frame.maxY <= bottom && (element.isHittable || element.elementType == .textField) { return }
            let targetY = (top + bottom) / 2
            let distance = min(max(24, abs(element.frame.midY - targetY)), max(24, (bottom - top) * 0.7))
            let movingDown = element.frame.midY < targetY
            let startY = movingDown ? top : bottom
            let endY = movingDown ? top + distance : bottom - distance
            let first = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: form.frame.midX, dy: startY))
            let last = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: form.frame.midX, dy: endY))
            first.press(forDuration: 0.08, thenDragTo: last, withVelocity: .slow, thenHoldForDuration: 0.2)
        }
        XCTAssertTrue(element.isHittable, app.debugDescription)
    }
    private func attach(_ app: XCUIApplication, _ name: String) {
        let a = XCTAttachment(screenshot: app.screenshot()); a.name = name; a.lifetime = .keepAlways; add(a)
    }
}
