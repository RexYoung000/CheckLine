import XCTest

@MainActor final class NativePortUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure=false
        if #available(iOS 27.0,*) { try XCUIDevice.shared.voiceOverService.disable() }
    }
    func testTwoTabsAndHolderLayersDoNotSwitchOnBlankTap() {
        let app=launch("budgets")
        XCTAssertTrue(app.buttons["wallet.home.capture"].waitForExistence(timeout: 10),app.debugDescription)
        XCTAssertFalse(app.buttons["wallet.tab.insights"].exists)
        XCTAssertFalse(app.buttons["wallet.tab.home"].exists)
        let down=app.buttons["native.holder.down"]
        XCTAssertTrue(down.waitForExistence(timeout: 5),app.debugDescription)
        down.tap()
        let library=app.descendants(matching: .any)["native.budget.library"]
        XCTAssertTrue(library.waitForExistence(timeout: 5),app.debugDescription)
        let holder=app.descendants(matching: .any)["native.holder.surface"].firstMatch
        holder.coordinate(withNormalizedOffset: CGVector(dx: 0.025,dy: 0.5)).tap()
        XCTAssertTrue(library.exists,"A blank tap must not dismiss the library.")
        attach(app,"native-library-arc")
        app.buttons["切换排布"].firstMatch.tap()
        attach(app,"native-library-sphere")
        app.buttons["native.library.close"].tap()
        XCTAssertTrue(library.waitForNonExistence(timeout: 5))
        XCTAssertTrue(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "value CONTAINS %@", "已就绪"),object: holder)],timeout: 5) == .completed)
        app.buttons["native.holder.up"].tap()
        let records=app.descendants(matching: .any)["native.budget.records"]
        XCTAssertTrue(records.waitForExistence(timeout: 5),app.debugDescription)
        attach(app,"native-records-layer")
        holder.coordinate(withNormalizedOffset: CGVector(dx: 0.025,dy: 0.5)).tap()
        XCTAssertTrue(records.exists,"A blank tap must not dismiss records.")
        app.buttons["native.holder.down"].tap()
        XCTAssertTrue(app.buttons["wallet.home.capture"].waitForExistence(timeout: 5))
    }
    func testHolderDragAndCompactWindowDragReturn() {
        let app=launch("budgets")
        let holder=app.otherElements["native.holder.surface"].firstMatch
        XCTAssertTrue(holder.waitForExistence(timeout: 10),app.debugDescription)
        let start=holder.coordinate(withNormalizedOffset: CGVector(dx: 0.02,dy: 0.6))
        start.press(forDuration: 0.05,thenDragTo: start.withOffset(CGVector(dx: 0,dy: -190)))
        let records=app.descendants(matching: .any)["native.budget.records"]
        XCTAssertTrue(records.waitForExistence(timeout: 5),app.debugDescription)
        attach(app,"native-drag-records")
        let window=app.otherElements["wallet.home.card"].firstMatch
        let bar=window.coordinate(withNormalizedOffset: CGVector(dx: 0.5,dy: 0.5))
        bar.press(forDuration: 0.05,thenDragTo: bar.withOffset(CGVector(dx: 0,dy: 170)))
        XCTAssertTrue(app.buttons["wallet.home.capture"].waitForExistence(timeout: 5),app.debugDescription)
        attach(app,"native-drag-restored")
    }
    func testWishFlipPurchaseResultAndRealizedList() {
        let app=launch("redemption")
        let amount=app.textFields["wallet.wishes.actual"]
        XCTAssertTrue(amount.waitForExistence(timeout: 10),app.debugDescription)
        amount.tap();amount.typeText("300")
        app.buttons["完成输入"].firstMatch.tap()
        let consent=app.switches["wallet.wishes.purchaseConfirmed"]
        reveal(consent,app);consent.tap()
        app.buttons["wallet.wishes.confirm"].tap()
        let result=app.descendants(matching: .any)["native.outcome.result"]
        XCTAssertTrue(result.waitForExistence(timeout: 5),app.debugDescription)
        XCTAssertTrue(app.buttons["查看已实现"].isHittable)
        attach(app,"native-wish-result")
        app.buttons["查看已实现"].tap()
        XCTAssertTrue(result.waitForNonExistence(timeout: 5))
    }
    func testSettlementReceivesInCurrentPage() {
        let app=launch("settlement-loop")
        app.staticTexts["周末旅行"].firstMatch.tap()
        let settle=app.buttons["wallet.budget.settlement"]
        XCTAssertTrue(settle.waitForExistence(timeout: 8),app.debugDescription)
        reveal(settle,app);settle.tap()
        let accept=app.buttons["wallet.settlement.acceptData"]
        XCTAssertTrue(accept.waitForExistence(timeout: 5));reveal(accept,app);accept.tap()
        app.buttons["wallet.settlement.confirm"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["native.outcome.result"].waitForExistence(timeout: 5),app.debugDescription)
        XCTAssertTrue(app.staticTexts["周末旅行"].exists)
        XCTAssertTrue(app.buttons["回到预算"].exists)
        attach(app,"native-settlement-result-current-page")
    }
    func testCoverUpdatesWithinSameSheetAndUnpricedWishCannotRedeem() {
        let app=launch("wishes")
        XCTAssertTrue(app.buttons["wallet.header.create"].waitForExistence(timeout: 10))
        app.buttons["wallet.header.create"].tap()
        let name=app.textFields["wallet.wishes.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 10));name.tap();name.typeText("Cover test")
        app.buttons["完成输入"].firstMatch.tap()
        app.buttons["native.cover.open"].tap()
        XCTAssertTrue(app.navigationBars["心愿封面"].waitForExistence(timeout: 5))
        app.buttons["旅行"].tap()
        XCTAssertTrue(app.navigationBars["心愿封面"].exists)
        app.buttons["摄影"].tap()
        app.segmentedControls.buttons["我的图片"].tap()
        XCTAssertTrue(app.buttons["选择图片"].exists)
        app.segmentedControls.buttons["预设图标"].tap()
        app.buttons["使用封面"].tap()
        XCTAssertEqual(name.value as? String,"Cover test")
        app.buttons["wallet.wishes.create.save"].tap()
        XCTAssertTrue(app.staticTexts["Cover test"].waitForExistence(timeout: 5),app.debugDescription)
        app.staticTexts["Cover test"].tap()
        let redeem=app.buttons["native.wish.redeem"].firstMatch
        XCTAssertTrue(redeem.waitForExistence(timeout: 5));XCTAssertFalse(redeem.isEnabled)
        attach(app,"native-unpriced-wish-disabled")
    }
    func testEnglishDarkLargeTextBalanceAndUnpricedWish() {
        let app=XCUIApplication()
        app.launchArguments=["-design-preview","-design-screen","wishes-empty","-checkline.appearance","dark","-AppleLanguages","(en)","-AppleLocale","en_US","-UIPreferredContentSizeCategoryName","UICTContentSizeCategoryAccessibilityXXXL","-design-reduce-motion"]
        app.launch()
        let balance=app.buttons["native.wish.balance"]
        XCTAssertTrue(balance.waitForExistence(timeout: 10));balance.tap()
        XCTAssertTrue(app.staticTexts["wallet.wishes.balance.detail"].waitForExistence(timeout: 5))
        attach(app,"native-small-dark-large-balance")
        app.buttons["Close"].firstMatch.tap()
        app.buttons["wallet.header.create"].tap()
        let name=app.textFields["wallet.wishes.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5));name.tap();name.typeText("A little adventure")
        if app.buttons["Done"].firstMatch.exists { app.buttons["Done"].firstMatch.tap() }
        let save=app.buttons["wallet.wishes.create.save"]
        XCTAssertTrue(save.isHittable);save.tap()
        let title=app.staticTexts["A little adventure"]
        XCTAssertTrue(title.waitForExistence(timeout: 5));reveal(title,app);title.tap()
        let redeem=app.buttons["native.wish.redeem"].firstMatch
        XCTAssertTrue(redeem.waitForExistence(timeout: 5));XCTAssertFalse(redeem.isEnabled)
        XCTAssertTrue(app.buttons["native.wish.fillPrice"].firstMatch.isHittable,"Reduced-motion back face must be visible and actionable, not merely present in the accessibility tree.")
        attach(app,"native-small-dark-large-unpriced-wish")
        app.buttons["native.wish.fillPrice"].firstMatch.tap()
        let price=app.textFields["native.wish.price.amount"]
        XCTAssertTrue(price.waitForExistence(timeout: 5));price.tap();price.typeText("120")
        if app.buttons["Done"].firstMatch.exists { app.buttons["Done"].firstMatch.tap() }
        let priceSave=app.buttons["native.wish.price.save"]
        XCTAssertTrue(priceSave.isHittable);priceSave.tap()
        XCTAssertTrue(app.buttons["native.wish.redeem"].firstMatch.isEnabled)
    }
    func testVoiceOverReachesHolderActionsAndBudgetAmount() throws {
        guard #available(iOS 27.0,*) else { throw XCTSkip("VoiceOver automation requires iOS 27.") }
        let app=launch("budgets")
        XCTAssertTrue(app.buttons["wallet.home.capture"].waitForExistence(timeout: 10))
        let voice=XCUIDevice.shared.voiceOverService
        try voice.enable();defer { try? voice.disable() }
        var spoken:[String]=[]
        var foundAmount=false,foundLibrary=false
        for _ in 0..<36 {
            let utterance=try voice.moveForward().utterance
            spoken.append(utterance)
            if utterance.contains("1,280") || utterance.contains("1280") || utterance.contains("一千二百八十") { foundAmount=true }
            if utterance.contains("预算卡库") { foundLibrary=true }
            if foundAmount && foundLibrary { break }
        }
        let evidence=XCTAttachment(string: spoken.joined(separator: "\n"));evidence.name="native-budget-voiceover";evidence.lifetime = .keepAlways;add(evidence)
        XCTAssertTrue(foundAmount,spoken.joined(separator: "\n"))
        XCTAssertTrue(foundLibrary,spoken.joined(separator: "\n"))
    }
    func testAgentWishDraftRequiresExplicitReviewAndConfirmation() {
        let app=launch("agent")
        let input=app.descendants(matching: .any)["wallet.agent.input"].firstMatch
        XCTAssertTrue(input.waitForExistence(timeout: 10));input.tap();input.typeText("想买耳机，1200元")
        app.buttons["wallet.agent.send"].tap()
        let review=app.buttons["查看心愿草稿"]
        XCTAssertTrue(review.waitForExistence(timeout: 5),app.debugDescription)
        review.tap()
        let name=app.textFields["wallet.wishes.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5));XCTAssertEqual(name.value as? String,"耳机")
        XCTAssertEqual(app.textFields["wallet.wishes.estimate"].value as? String,"1200")
        app.buttons["wallet.wishes.create.save"].tap()
        let message=app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "已添加「耳机」")).firstMatch
        XCTAssertTrue(message.waitForExistence(timeout: 5),app.debugDescription)
        attach(app,"native-agent-wish-created")
    }
    func testExpandedWishPurchaseReturnsToRealizedList() {
        let app=launch("wishes")
        let expand=app.buttons["native.wish.expand"].firstMatch
        XCTAssertTrue(expand.waitForExistence(timeout: 10));expand.tap()
        XCTAssertTrue(app.descendants(matching: .any)["native.wish.expanded"].waitForExistence(timeout: 5),app.debugDescription)
        let card=app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@", "native.wish.card.")).firstMatch
        card.coordinate(withNormalizedOffset: CGVector(dx: 0.5,dy: 0.5)).tap()
        let redeem=app.buttons["native.wish.redeem"].firstMatch
        XCTAssertTrue(redeem.waitForExistence(timeout: 5));redeem.tap()
        let amount=app.textFields["wallet.wishes.actual"]
        XCTAssertTrue(amount.waitForExistence(timeout: 5));amount.tap();amount.typeText("300")
        app.buttons["完成输入"].firstMatch.tap()
        let consent=app.switches["wallet.wishes.purchaseConfirmed"]
        reveal(consent,app);consent.tap()
        app.buttons["wallet.wishes.confirm"].tap()
        XCTAssertTrue(app.buttons["查看已实现"].waitForExistence(timeout: 5))
        app.buttons["查看已实现"].tap()
        XCTAssertTrue(app.buttons["native.wish.balance"].waitForExistence(timeout: 5),app.debugDescription)
        XCTAssertTrue(app.segmentedControls["native.wish.tabs"].buttons["已实现"].isSelected)
        attach(app,"native-expanded-purchase-realized-list")
    }
    func testDiscardAgentWishRemovesPendingProposal() {
        let app=launch("agent")
        let input=app.descendants(matching: .any)["wallet.agent.input"].firstMatch
        XCTAssertTrue(input.waitForExistence(timeout: 10));input.tap();input.typeText("想买耳机，1200元")
        app.buttons["wallet.agent.send"].tap()
        let review=app.buttons["查看心愿草稿"]
        XCTAssertTrue(review.waitForExistence(timeout: 5));review.tap()
        XCTAssertTrue(app.textFields["wallet.wishes.name"].waitForExistence(timeout: 5))
        app.navigationBars["添加心愿"].buttons["任务选项"].tap()
        app.buttons["放弃这份草稿"].tap()
        app.alerts.buttons["放弃草稿"].tap()
        app.navigationBars["添加心愿"].buttons["关闭"].tap()
        XCTAssertTrue(input.waitForExistence(timeout: 5),"Discarding a wish draft must return to the same Agent task panel.")
        XCTAssertTrue(review.waitForNonExistence(timeout: 5),app.debugDescription)
    }
    private func launch(_ screen: String)->XCUIApplication {
        let app=XCUIApplication()
        app.launchArguments=["-design-preview","-design-screen",screen,"-AppleLanguages","(zh-Hans)","-AppleLocale","zh_CN"]
        app.launch();return app
    }
    private func reveal(_ element: XCUIElement,_ app: XCUIApplication) {
        for _ in 0..<8 { if element.isHittable { return };app.scrollViews.firstMatch.swipeUp(velocity: .slow) }
    }
    private func attach(_ app: XCUIApplication,_ name: String) {
        let shot=XCTAttachment(screenshot: app.screenshot());shot.name=name;shot.lifetime = .keepAlways;add(shot)
    }
}
