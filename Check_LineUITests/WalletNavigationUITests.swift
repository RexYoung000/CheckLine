import XCTest
import UIKit

@MainActor
final class WalletNavigationUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    func testFloatingHeaderRemainsUsableWhileScrolling() throws {
        let app = launch(screen: "home")
        let profile = app.buttons["wallet.profile"]
        let attention = app.buttons["wallet.attention"]
        let functions = app.buttons["wallet.functions"]
        XCTAssertTrue(profile.waitForExistence(timeout: 10))
        XCTAssertTrue(attention.exists)
        XCTAssertTrue(functions.exists)
        XCTAssertGreaterThan(attention.frame.minX - profile.frame.maxX, 40)
        XCTAssertGreaterThanOrEqual(profile.frame.width, 43)
        XCTAssertGreaterThanOrEqual(attention.frame.width, 43)
        XCTAssertGreaterThanOrEqual(functions.frame.width, 43)
        attach(app, name: "floating-header-home")

        app.swipeUp()
        XCTAssertTrue(profile.isHittable)
        XCTAssertTrue(attention.isHittable)
        XCTAssertTrue(functions.isHittable)
        attach(app, name: "floating-header-over-scrolled-content")

        attention.tap()
        XCTAssertTrue(app.navigationBars["待处理事项"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.navigationBars["待处理事项"].waitForNonExistence(timeout: 5))

        app.buttons["wallet.tab.budgets"].tap()
        let create = app.buttons["wallet.header.create"]
        XCTAssertTrue(create.waitForExistence(timeout: 5))
        XCTAssertTrue(create.isHittable)
        XCTAssertGreaterThanOrEqual(create.frame.width, 43)
        attach(app, name: "floating-header-dark-page")
        create.tap()
        XCTAssertTrue(app.textFields.firstMatch.waitForExistence(timeout: 5))
    }

    func testFloatingHeaderProfileAndMenuOpenTheirDestinations() throws {
        let app = launch(screen: "home")
        let profile = app.buttons["wallet.profile"]
        XCTAssertTrue(profile.waitForExistence(timeout: 10))
        profile.tap()
        XCTAssertTrue(app.navigationBars["设置"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.navigationBars["设置"].waitForNonExistence(timeout: 5))

        app.buttons["wallet.functions"].tap()
        let record = app.buttons["记一笔"].firstMatch
        XCTAssertTrue(record.waitForExistence(timeout: 5))
        attach(app, name: "function-menu-icons")
        record.tap()
        XCTAssertTrue(app.textFields.firstMatch.waitForExistence(timeout: 5))
    }

    func testNativeTabsAndAgentKeepTheCurrentPage() throws {
        guard #available(iOS 27.0, *) else { throw XCTSkip("Native prominent tabs require iOS 27.") }
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .phone, "iPad retains the centered custom navigation.")
        let app = launch(screen: "home")
        let bar = app.tabBars.firstMatch
        XCTAssertTrue(bar.waitForExistence(timeout: 10))
        XCTAssertEqual(bar.buttons.count, 5, app.debugDescription)

        for index in [1, 2, 3, 0, 2, 1] {
            let tab = bar.buttons.element(boundBy: index)
            tab.tap()
            XCTAssertTrue(tab.isSelected)
        }
        let budget = bar.buttons.element(boundBy: 1)
        let agent = bar.buttons.element(boundBy: 4)
        XCTAssertEqual(budget.frame.midY, agent.frame.midY, accuracy: 4)
        XCTAssertGreaterThan(agent.frame.minX, bar.buttons.element(boundBy: 3).frame.maxX)
        attach(app, name: "native-tabs-before-agent")

        for _ in 0..<2 {
            agent.tap()
            let close = app.buttons["wallet.agent.close"]
            XCTAssertTrue(close.waitForExistence(timeout: 5), app.debugDescription)
            attach(app, name: "agent-sheet")
            close.tap()
            XCTAssertTrue(budget.waitForExistence(timeout: 5))
            XCTAssertTrue(budget.isSelected, "Closing Agent must preserve the selected page.")
        }
        attach(app, name: "native-tabs-after-agent")
    }

    func testEmptyHomeOffersReadableCreation() throws {
        let app = launch(screen: "empty")
        let create = app.buttons["wallet.empty.createBudget"]
        let emptyCard = app.buttons["wallet.empty.card"]
        XCTAssertTrue(create.waitForExistence(timeout: 10))
        XCTAssertTrue(emptyCard.isHittable)
        XCTAssertFalse(app.staticTexts["为日常开销或一个计划，创建一张预算卡。"].exists)
        XCTAssertTrue(create.isHittable)
        attach(app, name: "empty-home")
        emptyCard.tap()
        let agentClose = app.buttons["wallet.agent.close"]
        XCTAssertTrue(agentClose.waitForExistence(timeout: 5))
        agentClose.tap()
        create.tap()
        XCTAssertTrue(app.textFields.firstMatch.waitForExistence(timeout: 5))
        attach(app, name: "create-from-empty-home")

        let name = app.textFields["输入预算名称"]
        name.tap()
        name.typeText("导航测试")
        let amount = app.textFields["额度"]
        amount.tap()
        amount.typeText("500")
        app.buttons.matching(NSPredicate(format: "label == %@ AND identifier != %@", "创建预算卡", "wallet.empty.createBudget")).firstMatch.tap()
        let undo = app.buttons["撤销"]
        XCTAssertTrue(undo.waitForExistence(timeout: 5))
        attach(app, name: "creation-feedback-above-tabs")
        if #available(iOS 27.0, *), UIDevice.current.userInterfaceIdiom == .phone {
            XCTAssertLessThanOrEqual(undo.frame.maxY, app.tabBars.firstMatch.frame.minY,
                                     "Action feedback must remain above the system tab bar.")
        }
        undo.tap()
        XCTAssertTrue(create.waitForExistence(timeout: 5))
    }

    func testEmptyHomeCreatesFirstCardThroughOfflineAgent() throws {
        let app = launch(screen: "empty")
        app.buttons["wallet.empty.card"].tap()
        let input = app.descendants(matching: .any)["wallet.agent.input"]
        XCTAssertTrue(input.waitForExistence(timeout: 5), app.debugDescription)
        input.tap()
        input.typeText("创建每月餐饮预算1000元")
        app.buttons["发送"].tap()
        let confirm = app.buttons["确认创建预算卡"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 8), app.debugDescription)
        confirm.tap()
        XCTAssertTrue(app.buttons["wallet.agent.close"].waitForNonExistence(timeout: 5), app.debugDescription)
        XCTAssertFalse(app.buttons["wallet.empty.createBudget"].exists)
        XCTAssertTrue(app.staticTexts["餐饮"].waitForExistence(timeout: 5), app.debugDescription)
    }

    func testNormalAppKeepsFirstCardAfterRelaunch() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()
        let create = app.buttons["wallet.empty.createBudget"]
        XCTAssertTrue(create.waitForExistence(timeout: 10), app.debugDescription)
        create.tap()
        let name = app.textFields["输入预算名称"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText("重开测试")
        let amount = app.textFields["额度"]
        amount.tap()
        amount.typeText("500")
        app.buttons.matching(NSPredicate(format: "label == %@ AND identifier != %@", "创建预算卡", "wallet.empty.createBudget")).firstMatch.tap()
        XCTAssertTrue(app.staticTexts["重开测试"].waitForExistence(timeout: 5), app.debugDescription)
        app.terminate()
        app.launch()
        XCTAssertFalse(create.waitForExistence(timeout: 3), app.debugDescription)
        XCTAssertTrue(app.staticTexts["重开测试"].waitForExistence(timeout: 8), app.debugDescription)
    }

    func testAgentDraftMovesIntoManualBudgetForm() throws {
        let app = launch(screen: "empty")
        app.buttons["wallet.empty.card"].tap()
        let input = app.descendants(matching: .any)["wallet.agent.input"]
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        input.tap()
        input.typeText("创建预算卡")
        app.buttons["发送"].tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "这张预算卡叫什么名字？")).firstMatch.waitForExistence(timeout: 5))
        input.tap()
        input.typeText("餐饮 1000元 每月")
        app.buttons["wallet.task.switchMode"].tap()
        let name = app.textFields["输入预算名称"]
        XCTAssertTrue(name.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertEqual(name.value as? String, "餐饮")
        XCTAssertEqual(app.textFields["额度"].value as? String, "1000")
    }

    func testOneShotSettlementReachesWishWalletAndRealPurchase() throws {
        let app = launch(screen: "settlement-loop")
        let budgetCard = app.buttons["周末旅行"].firstMatch
        XCTAssertTrue(budgetCard.waitForExistence(timeout: 10), app.debugDescription)
        budgetCard.tap()
        let settle = app.buttons["wallet.budget.settlement"]
        XCTAssertTrue(settle.waitForExistence(timeout: 5), app.debugDescription)
        settle.tap()
        XCTAssertTrue(app.staticTexts["结算后会怎样"].waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(app.staticTexts["未连接的来源与漏记消费不会自动出现在此处；空白日期不代表没有消费。"].exists)
        attach(app, name: "settlement-review")

        let confirm = app.buttons["wallet.settlement.confirm"]
        XCTAssertFalse(confirm.isEnabled)
        app.buttons["wallet.settlement.acceptData"].tap()
        XCTAssertTrue(confirm.isEnabled, app.debugDescription)
        confirm.tap()
        XCTAssertTrue(app.staticTexts["本期已结算"].waitForExistence(timeout: 5), app.debugDescription)
        attach(app, name: "settlement-saved")
        app.buttons["wallet.settlement.viewWishes"].tap()
        XCTAssertTrue(app.staticTexts["¥750"].waitForExistence(timeout: 5), app.debugDescription)

        app.buttons["添加心愿"].firstMatch.tap()
        let name = app.textFields["心愿名称"]
        XCTAssertTrue(name.waitForExistence(timeout: 5), app.debugDescription)
        name.tap()
        name.typeText("耳机")
        app.buttons["添加心愿"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["耳机"].waitForExistence(timeout: 5), app.debugDescription)
        app.staticTexts["耳机"].tap()
        app.buttons["已购买，去兑现"].tap()
        let actual = app.textFields["实际花费"]
        XCTAssertTrue(actual.waitForExistence(timeout: 5), app.debugDescription)
        actual.tap()
        actual.typeText("500")
        app.switches["我已完成真实购买"].tap()
        app.buttons["确认兑现"].tap()
        XCTAssertTrue(app.staticTexts["这个心愿，实现了"].waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(app.staticTexts["¥250"].exists, app.debugDescription)
        attach(app, name: "wish-redeemed-from-settlement")
    }

    func testAnalysisEmptyStatesUseRealDataAndOfferNextAction() throws {
        let withoutCard = launch(screen: "analysis-empty")
        XCTAssertTrue(withoutCard.staticTexts["还没有可回看的预算卡"].waitForExistence(timeout: 10))
        XCTAssertTrue(withoutCard.buttons["创建预算卡"].isHittable)
        XCTAssertFalse(withoutCard.staticTexts["-¥0"].exists)
        withoutCard.terminate()

        let withoutRecords = launch(screen: "analysis-no-records")
        XCTAssertTrue(withoutRecords.staticTexts["还没有消费记录"].waitForExistence(timeout: 10))
        XCTAssertTrue(withoutRecords.buttons["记一笔"].isHittable)
        XCTAssertFalse(withoutRecords.staticTexts["-¥0"].exists)
    }

    func testNativeLensDragAndDetailReturn() throws {
        guard #available(iOS 27.0, *) else { throw XCTSkip("Native prominent tabs require iOS 27.") }
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .phone, "iPad retains the centered custom navigation.")
        let app = launch(screen: "home")
        let bar = app.tabBars.firstMatch
        XCTAssertTrue(bar.waitForExistence(timeout: 10))
        let home = bar.buttons.element(boundBy: 0)
        let analysis = bar.buttons.element(boundBy: 3)
        home.press(forDuration: 0.2, thenDragTo: analysis)
        XCTAssertTrue(analysis.isSelected)
        analysis.press(forDuration: 0.2, thenDragTo: home)
        XCTAssertTrue(home.isSelected)

        bar.buttons.element(boundBy: 2).tap()
        app.staticTexts["一副新耳机"].tap()
        XCTAssertTrue(bar.waitForNonExistence(timeout: 5), "A pushed detail must hide the root tab bar.")
        attach(app, name: "wish-detail-without-tab-bar")
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(bar.waitForExistence(timeout: 5))
        XCTAssertTrue(bar.buttons.element(boundBy: 2).isSelected)
    }

    private func launch(screen: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-design-preview", "-design-screen", screen, "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()
        return app
    }

    private func attach(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
