import XCTest
import UIKit

@MainActor
final class WalletNavigationUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        if #available(iOS 27.0, *) { try XCUIDevice.shared.voiceOverService.disable() }
    }

    func testBudgetHeaderRemainsUsableAcrossHolderLayers() {
        let app = launch(screen: "r34-home")
        let create = app.buttons["wallet.header.create"]
        let profile = app.buttons["wallet.profile"]
        XCTAssertTrue(create.waitForExistence(timeout: 10))
        XCTAssertTrue(profile.isHittable)
        XCTAssertGreaterThanOrEqual(create.frame.width, 43)
        XCTAssertGreaterThanOrEqual(profile.frame.width, 43)
        let headerY = create.frame.midY

        app.buttons["native.holder.up"].tap()
        XCTAssertTrue(element("native.budget.records", in: app).waitForExistence(timeout: 5))
        XCTAssertTrue(create.isHittable)
        XCTAssertTrue(profile.isHittable)
        XCTAssertEqual(create.frame.midY, headerY, accuracy: 3)
        app.buttons["native.holder.down"].tap()
        XCTAssertTrue(app.buttons["wallet.home.capture"].waitForExistence(timeout: 5))
        app.buttons["native.holder.down"].tap()
        XCTAssertTrue(element("native.budget.library", in: app).waitForExistence(timeout: 5))
        XCTAssertTrue(create.isHittable)
        XCTAssertTrue(profile.isHittable)
        XCTAssertEqual(create.frame.midY, headerY, accuracy: 3)
        attach(app, name: "budget-header-over-library")

        create.tap()
        XCTAssertTrue(app.textFields["wallet.composer.name"].waitForExistence(timeout: 5))
        app.buttons["wallet.composer.close"].tap()
        XCTAssertTrue(app.buttons["native.library.close"].isHittable)
    }

    func testBudgetSettingsAndRecordOpenFromTheirNativeEntries() {
        let app = launch(screen: "r34-home")
        let profile = app.buttons["wallet.profile"]
        XCTAssertTrue(profile.waitForExistence(timeout: 10))
        profile.tap()
        XCTAssertTrue(app.navigationBars["设置"].waitForExistence(timeout: 5))
        app.navigationBars["设置"].buttons.firstMatch.tap()
        XCTAssertTrue(app.navigationBars["设置"].waitForNonExistence(timeout: 5))

        let record = app.buttons["wallet.home.capture"]
        XCTAssertTrue(record.isHittable)
        record.tap()
        XCTAssertTrue(app.textFields["wallet.composer.amount"].waitForExistence(timeout: 5))
        app.buttons["wallet.composer.close"].tap()
        XCTAssertTrue(record.isHittable)
    }

    func testNativeTabsAndAgentKeepTheCurrentPage() {
        let app = launch(screen: "r34-home")
        XCTAssertTrue(app.buttons["wallet.home.capture"].waitForExistence(timeout: 10))
        let budget = tab("budgets", title: "预算", in: app)
        let wish = tab("wishes", title: "心愿", in: app)
        let agent = app.buttons["wallet.agent.avatar"]
        XCTAssertTrue(budget.isSelected)
        let nativeBar = app.tabBars["wallet.nativeTabBar"]
        if nativeBar.exists { XCTAssertEqual(nativeBar.buttons.count, 2) }
        XCTAssertEqual(budget.frame.midY, agent.frame.midY, accuracy: 9)
        XCTAssertGreaterThan(agent.frame.minX, wish.frame.maxX)

        for (page, visibleControl) in [(wish, "native.wish.layout"), (budget, "wallet.home.capture")] {
            page.tap()
            XCTAssertTrue(app.buttons[visibleControl].waitForExistence(timeout: 5))
            XCTAssertTrue(page.isSelected)
            agent.tap()
            let close = app.buttons["wallet.agent.close"]
            XCTAssertTrue(close.waitForExistence(timeout: 5))
            close.tap()
            XCTAssertTrue(close.waitForNonExistence(timeout: 5))
            XCTAssertTrue(page.isSelected)
            XCTAssertTrue(app.buttons[visibleControl].isHittable)
        }
    }

    func testEmptyHomeOffersReadableCreation() {
        let app = launch(screen: "budget-empty")
        let emptyCard = app.buttons["wallet.empty.card"]
        let manual = app.buttons["手动填写"]
        XCTAssertTrue(emptyCard.waitForExistence(timeout: 10))
        XCTAssertTrue(emptyCard.isHittable)
        XCTAssertTrue(manual.isHittable)
        XCTAssertFalse(app.staticTexts["为日常开销或一个计划，创建一张预算卡。"].exists)

        emptyCard.tap()
        XCTAssertTrue(app.textFields["wallet.composer.name"].waitForExistence(timeout: 5))
        app.buttons["wallet.composer.close"].tap()
        XCTAssertTrue(emptyCard.isHittable)
        manual.tap()
        enterBudget(name: "导航测试", in: app)
        let undo = app.buttons["撤销"]
        XCTAssertTrue(undo.waitForExistence(timeout: 5))
        XCTAssertTrue(element("wallet.home.card", in: app).staticTexts["导航测试"].exists)
        let budget = tab("budgets", title: "预算", in: app)
        XCTAssertLessThanOrEqual(undo.frame.maxY, budget.frame.minY)
        undo.tap()
        XCTAssertTrue(emptyCard.waitForExistence(timeout: 5))
        XCTAssertFalse(element("wallet.home.card", in: app).exists)
    }

    func testEmptyHomeCreatesFirstCardThroughOfflineAgent() {
        let app = launch(screen: "budget-empty")
        XCTAssertTrue(app.buttons["wallet.empty.card"].waitForExistence(timeout: 10))
        app.buttons["wallet.agent.avatar"].tap()
        let input = element("wallet.agent.input", in: app)
        XCTAssertTrue(input.waitForExistence(timeout: 5), app.debugDescription)
        input.tap()
        input.typeText("创建每月餐饮预算1000元")
        app.buttons["wallet.agent.send"].tap()
        let confirm = app.buttons["确认创建预算卡"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 8), app.debugDescription)
        confirm.tap()
        XCTAssertTrue(app.buttons["wallet.agent.close"].waitForNonExistence(timeout: 5))
        XCTAssertFalse(app.buttons["wallet.empty.card"].exists)
        XCTAssertTrue(element("wallet.home.card", in: app).staticTexts["餐饮"].waitForExistence(timeout: 5))
    }

    func testNormalAppKeepsCreatedCardAfterRelaunch() {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()
        let create = app.buttons["wallet.header.create"]
        XCTAssertTrue(create.waitForExistence(timeout: 10), app.debugDescription)
        let name = "重开测试 " + String(UUID().uuidString.prefix(8))
        create.tap()
        enterBudget(name: name, in: app)
        let home = element("wallet.home.card", in: app)
        XCTAssertTrue(home.staticTexts[name].waitForExistence(timeout: 5))
        app.terminate()
        app.launch()
        XCTAssertTrue(home.waitForExistence(timeout: 8))
        if !home.staticTexts[name].exists {
            app.buttons["native.holder.down"].tap()
            let search = app.buttons["native.library.search"]
            XCTAssertTrue(search.waitForExistence(timeout: 5))
            search.tap()
            let field = app.textFields["native.library.searchField"]
            XCTAssertTrue(field.waitForExistence(timeout: 5))
            field.tap()
            field.typeText(name)
            let card = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label BEGINSWITH %@", "native.library.card.", name)).firstMatch
            XCTAssertTrue(card.waitForExistence(timeout: 5))
            card.tap()
        }
        XCTAssertTrue(home.staticTexts[name].waitForExistence(timeout: 5))
    }

    func testAgentDraftMovesIntoManualBudgetForm() {
        let app = launch(screen: "budget-empty")
        XCTAssertTrue(app.buttons["wallet.empty.card"].waitForExistence(timeout: 10))
        app.buttons["wallet.agent.avatar"].tap()
        let input = element("wallet.agent.input", in: app)
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        input.tap()
        input.typeText("创建预算卡")
        app.buttons["wallet.agent.send"].tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "这张预算卡叫什么名字？")).firstMatch.waitForExistence(timeout: 5))
        input.tap()
        input.typeText("餐饮 1000元 每月")
        app.buttons["wallet.task.switchMode"].tap()
        let name = app.textFields["wallet.composer.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertEqual(name.value as? String, "餐饮")
        XCTAssertEqual(app.textFields["wallet.composer.amount"].value as? String, "1000")
    }

    func testOneShotSettlementReachesWishWalletAndRealPurchase() {
        let app = launch(screen: "settlement-loop")
        let used = app.buttons["native.home.summary.used"]
        XCTAssertTrue(used.waitForExistence(timeout: 10))
        used.tap()
        let settle = app.buttons["wallet.budget.settlement"]
        reveal(settle, in: app)
        settle.tap()

        let accept = app.buttons["wallet.settlement.acceptData"]
        let confirm = app.buttons["wallet.settlement.confirm"]
        XCTAssertTrue(accept.waitForExistence(timeout: 5))
        XCTAssertFalse(confirm.isEnabled)
        accept.tap()
        XCTAssertTrue(confirm.isEnabled)
        confirm.tap()
        let result = element("native.outcome.result", in: app)
        XCTAssertTrue(result.waitForExistence(timeout: 5))
        XCTAssertTrue(result.descendants(matching: .any)["native.outcome.wallet"].label.contains("750"))
        XCTAssertTrue(app.buttons["native.outcome.skip"].waitForNonExistence(timeout: 6))
        app.buttons["回到预算"].tap()
        XCTAssertTrue(result.waitForNonExistence(timeout: 5))
        if app.buttons["wallet.budget.detail.close"].isHittable { app.buttons["wallet.budget.detail.close"].tap() }
        XCTAssertTrue(app.buttons["wallet.empty.card"].waitForExistence(timeout: 5), "The one-shot budget is archived after settlement.")

        tab("wishes", title: "心愿", in: app).tap()
        let balance = app.buttons["native.wish.balance"]
        XCTAssertTrue(balance.waitForExistence(timeout: 5))
        XCTAssertTrue(balance.label.contains("750"))
        app.buttons["wallet.wishes.empty.add"].tap()
        let name = app.textFields["wallet.wishes.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap(); name.typeText("耳机")
        dismissKeyboard(in: app)
        let estimate = app.textFields["wallet.wishes.estimate"]
        reveal(estimate, in: app)
        estimate.tap(); estimate.typeText("500")
        dismissKeyboard(in: app)
        app.buttons["wallet.wishes.create.save"].tap()
        XCTAssertTrue(balance.waitForExistence(timeout: 5))
        XCTAssertTrue(balance.label.contains("750"), "Creating a wish must leave the wallet amount intact.")

        let wish = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label == %@", "native.wish.card.", "耳机")).firstMatch
        XCTAssertTrue(wish.waitForExistence(timeout: 5))
        let wishID = wish.identifier
        wish.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        let expanded = element("native.wish.expanded", in: app)
        XCTAssertTrue(expanded.waitForExistence(timeout: 5))
        let card = expanded.descendants(matching: .any)[wishID].firstMatch
        card.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        let redeem = card.buttons["native.wish.redeem"].firstMatch
        waitUntilHittable(redeem)
        XCTAssertTrue(redeem.isEnabled)
        redeem.tap()
        let actual = app.textFields["wallet.wishes.actual"]
        XCTAssertTrue(actual.waitForExistence(timeout: 5))
        actual.tap(); actual.typeText("500")
        dismissKeyboard(in: app)
        let purchase = app.buttons["wallet.wishes.confirm"]
        XCTAssertFalse(purchase.isEnabled)
        let consent = app.switches["wallet.wishes.purchaseConfirmed"]
        reveal(consent, in: app)
        consent.tap()
        XCTAssertTrue(purchase.isEnabled)
        purchase.tap()
        let realized = app.buttons["查看已实现"]
        XCTAssertTrue(realized.waitForExistence(timeout: 5))
        realized.tap()
        XCTAssertTrue(app.segmentedControls["native.wish.tabs"].buttons["已实现"].isSelected)
        XCTAssertTrue(wish.waitForExistence(timeout: 5))
        XCTAssertTrue(balance.label.contains("250"))
        attach(app, name: "wish-redeemed-from-settlement")
    }

    func testNewBudgetReachesEmptyRecordsAndCalendarThroughDetails() {
        let app = launch(screen: "budget-empty")
        let empty = app.buttons["wallet.empty.card"]
        XCTAssertTrue(empty.waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["native.home.summary.period"].exists)
        XCTAssertFalse(app.buttons["上个月"].exists)
        empty.tap()
        enterBudget(name: "空周期", in: app)
        let period = app.buttons["native.home.summary.period"]
        XCTAssertTrue(period.waitForExistence(timeout: 5))
        period.tap()
        XCTAssertTrue(app.buttons["上个月"].waitForExistence(timeout: 5))
        app.navigationBars["消费日历"].buttons.firstMatch.tap()
        let records = app.buttons["wallet.workspace.records"]
        reveal(records, in: app)
        records.tap()
        XCTAssertTrue(app.staticTexts["还没有记到这张卡的消费"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["-¥0"].exists)
        let record = app.buttons["wallet.budget.records.capture"]
        reveal(record, in: app)
        record.tap()
        let amount = app.textFields["wallet.composer.amount"]
        XCTAssertTrue(amount.waitForExistence(timeout: 5))
        XCTAssertTrue(app.scrollViews["wallet.workspace.page"].firstMatch.waitForNonExistence(timeout: 5))
        amount.tap(); amount.typeText("12.34")
        XCTAssertEqual(amount.value as? String, "12.34")
        dismissKeyboard(in: app)
        app.buttons["wallet.composer.close"].tap()
        XCTAssertTrue(amount.waitForNonExistence(timeout: 5))
        XCTAssertTrue(element("wallet.home.card", in: app).staticTexts["空周期"].exists)
        let capture = app.buttons["wallet.home.capture"]
        XCTAssertTrue(capture.isHittable)
        capture.tap()
        XCTAssertTrue(amount.waitForExistence(timeout: 5))
        XCTAssertEqual(amount.value as? String, "12.34")
    }

    func testNativeLensDragAndDetailReturn() {
        let app = launch(screen: "r34-home")
        XCTAssertTrue(app.buttons["wallet.home.capture"].waitForExistence(timeout: 10))
        let budget = tab("budgets", title: "预算", in: app)
        let wish = tab("wishes", title: "心愿", in: app)
        let center = CGVector(dx: 0.5, dy: 0.5)
        budget.coordinate(withNormalizedOffset: center).press(forDuration: 0.18, thenDragTo: wish.coordinate(withNormalizedOffset: center), withVelocity: .slow, thenHoldForDuration: 0.3)
        XCTAssertTrue(app.buttons["native.wish.layout"].waitForExistence(timeout: 5))
        XCTAssertTrue(wish.isSelected)
        wish.coordinate(withNormalizedOffset: center).press(forDuration: 0.18, thenDragTo: budget.coordinate(withNormalizedOffset: center), withVelocity: .slow, thenHoldForDuration: 0.3)
        XCTAssertTrue(app.buttons["wallet.home.capture"].waitForExistence(timeout: 5))
        XCTAssertTrue(budget.isSelected)

        wish.tap()
        let expand = app.buttons["native.wish.expand"].firstMatch
        XCTAssertTrue(expand.waitForExistence(timeout: 5))
        expand.tap()
        let expanded = element("native.wish.expanded", in: app)
        XCTAssertTrue(expanded.waitForExistence(timeout: 5))
        XCTAssertFalse(wish.isHittable)
        app.buttons["关闭"].firstMatch.tap()
        XCTAssertTrue(expanded.waitForNonExistence(timeout: 5))
        XCTAssertTrue(wish.isSelected)
        XCTAssertTrue(wish.isHittable)
    }

    private func enterBudget(name: String, in app: XCUIApplication) {
        let field = app.textFields["wallet.composer.name"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap(); field.typeText(name)
        dismissKeyboard(in: app)
        let amount = app.textFields["wallet.composer.amount"]
        reveal(amount, in: app)
        amount.tap(); amount.typeText("500")
        dismissKeyboard(in: app)
        app.buttons["wallet.composer.save"].tap()
        XCTAssertTrue(field.waitForNonExistence(timeout: 5))
    }

    private func dismissKeyboard(in app: XCUIApplication) {
        let done = app.buttons["完成输入"].firstMatch
        if done.isHittable { done.tap() }
    }

    private func reveal(_ control: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<6 where !control.isHittable {
            let scroll = app.scrollViews.firstMatch
            if scroll.exists { scroll.swipeUp(velocity: .slow) }
        }
        XCTAssertTrue(control.isHittable, app.debugDescription)
    }

    private func waitUntilHittable(_ control: XCUIElement) {
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == true AND enabled == true"), object: control)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 5), .completed)
    }

    private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    private func tab(_ id: String, title: String, in app: XCUIApplication) -> XCUIElement {
        let native = app.tabBars.buttons[title].firstMatch
        return native.exists ? native : app.buttons["wallet.tab.\(id)"].firstMatch
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
