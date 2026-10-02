import XCTest

@MainActor
final class TaskWorkspaceUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        if #available(iOS 27.0, *) { try XCUIDevice.shared.voiceOverService.disable() }
    }

    func testSharedTaskSwitchRetainsFieldsAndClosesToSamePage() {
        let app = launch("record")
        let amount = app.textFields["输入金额"]
        XCTAssertTrue(amount.waitForExistence(timeout: 8))
        amount.tap(); amount.typeText("12.34")
        let merchant = app.textFields["商家"]
        merchant.tap(); merchant.typeText("Sample shop")
        app.buttons["wallet.task.switchMode"].tap()
        XCTAssertTrue(app.buttons["wallet.agent.close"].waitForExistence(timeout: 5))
        attach(app, "task-agent-keeps-form")
        app.buttons["wallet.task.switchMode"].tap()
        XCTAssertEqual(amount.value as? String, "12.34")
        XCTAssertEqual(merchant.value as? String, "Sample shop")
        attach(app, "task-manual-keeps-fields")
        app.buttons["wallet.composer.close"].tap()
        XCTAssertTrue(app.buttons["wallet.tab.home"].waitForExistence(timeout: 5))
        app.buttons["记一笔"].firstMatch.tap()
        XCTAssertTrue(amount.waitForExistence(timeout: 5))
        XCTAssertEqual(amount.value as? String, "12.34")
    }

    func testVoiceEntryKeepsTheTaskAndManualFallback() {
        let app = launch("agent")
        let input = app.descendants(matching: .any).matching(identifier: "wallet.agent.input").firstMatch
        XCTAssertTrue(input.waitForExistence(timeout: 8))
        input.tap(); input.typeText("午餐 35 元")
        app.buttons["wallet.agent.voice"].tap()
        XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.alerts.staticTexts["语音输入尚未接通，可先输入文字。"].exists)
        app.alerts.buttons["关闭"].tap()
        XCTAssertEqual(input.value as? String, "午餐 35 元")
        app.buttons["wallet.task.switchMode"].tap()
        let amount = app.textFields["输入金额"]
        XCTAssertTrue(amount.waitForExistence(timeout: 5))
        XCTAssertEqual(amount.value as? String, "35")
        attach(app, "voice-fallback-retains-task")
    }

    func testCalendarDistinguishesDatesOutsideSelectedPeriod() {
        let app = launch("calendar")
        let previous = app.buttons["上个月"]
        XCTAssertTrue(previous.waitForExistence(timeout: 8))
        previous.tap()
        let outside = app.staticTexts["所选日期不在本周期"]
        XCTAssertTrue(outside.waitForExistence(timeout: 5))
        attach(app, "calendar-outside-selected-period")
        app.buttons["下个月"].tap()
        XCTAssertTrue(outside.waitForNonExistence(timeout: 5))
    }

    func testWorkspaceRecordsPendingDetailAndBackRestore() {
        let app = launch("home-inline")
        let records = app.buttons["wallet.workspace.records"]
        XCTAssertTrue(records.waitForExistence(timeout: 10), app.debugDescription)
        XCTAssertFalse(app.tabBars.firstMatch.isHittable)
        attach(app, "workspace-overview")
        records.tap()
        let pending = app.segmentedControls.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "待确认")).firstMatch
        XCTAssertTrue(pending.waitForExistence(timeout: 5), app.debugDescription)
        pending.tap()
        attach(app, "workspace-pending-directory")
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "咖啡")).firstMatch.tap()
        XCTAssertTrue(app.staticTexts["记录来源"].waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(app.buttons["确认当前归属"].exists)
        attach(app, "workspace-pending-detail")
        app.buttons["确认当前归属"].tap()
        XCTAssertTrue(app.staticTexts["已确认"].waitForExistence(timeout: 5))
        attach(app, "workspace-record-confirmed")
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(pending.waitForExistence(timeout: 5))
        XCTAssertTrue(pending.isSelected)
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(records.waitForExistence(timeout: 5))
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.buttons["wallet.tab.home"].waitForExistence(timeout: 5))
    }

    func testImportDesignStatesNeverClaimLiveConnection() {
        let app = launch("import-review")
        XCTAssertTrue(app.staticTexts["设计演示 · 虚构数据 · 不读取文件，不写入账本"].waitForExistence(timeout: 10))
        app.buttons["选择示例账单"].tap()
        app.buttons["继续核对"].tap()
        attach(app, "import-isolated-review")
        app.buttons["预览批量提交"].tap()
        XCTAssertTrue(app.staticTexts["将新增所选条目，重复项保持待核对。此演示不会提交真实数据。"].exists)
        app.buttons["确认示例结果"].tap()
        XCTAssertTrue(app.staticTexts["示例结果：1 笔新增、0 笔合并、1 笔未提交"].waitForExistence(timeout: 5))
        attach(app, "import-isolated-result")
        app.buttons["查看状态"].tap(); app.buttons["没有可导入的条目"].tap()
        XCTAssertTrue(app.staticTexts["没有可导入的条目"].firstMatch.waitForExistence(timeout: 5))
        attach(app, "import-isolated-empty")
        app.buttons["查看状态"].tap(); app.buttons["部分条目无法识别，核对进度已保留"].tap()
        XCTAssertTrue(app.buttons["重试未识别条目"].waitForExistence(timeout: 5))
        attach(app, "import-isolated-failure")
        app.buttons["重试未识别条目"].tap()
        XCTAssertTrue(app.buttons["预览批量提交"].waitForExistence(timeout: 5))
    }

    func testManagementDesignRecoveryAndImpactConfirmation() {
        let app = launch("management-review")
        XCTAssertTrue(app.buttons["预览示例纠正影响"].waitForExistence(timeout: 8))
        app.buttons["查看状态"].tap(); app.buttons["没有可管理的记录"].tap()
        XCTAssertTrue(app.staticTexts["没有可管理的记录"].waitForExistence(timeout: 5))
        attach(app, "management-isolated-empty")
        app.buttons["查看状态"].tap(); app.buttons["核对失败，修改内容已保留"].tap()
        XCTAssertTrue(app.buttons["重试保存草稿"].waitForExistence(timeout: 5))
        attach(app, "management-isolated-failure")
        app.buttons["重试保存草稿"].tap()
        XCTAssertTrue(app.staticTexts["正在重新核对示例影响"].waitForExistence(timeout: 5))
        app.buttons["继续核对"].tap()
        XCTAssertTrue(app.buttons["确认示例结果"].waitForExistence(timeout: 5))
        attach(app, "management-isolated-impact")
        app.buttons["确认示例结果"].tap()
        XCTAssertTrue(app.staticTexts["示例确认完成，账本未改变"].waitForExistence(timeout: 5))
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
