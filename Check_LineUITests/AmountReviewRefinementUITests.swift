import XCTest

@MainActor
final class AmountReviewRefinementUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        if #available(iOS 27.0, *) { try XCUIDevice.shared.voiceOverService.disable() }
    }

    func testCompletedWishMovesToRealizedAndKeepsDetailAndCreation() {
        let app = launch("wishes")
        let phases = app.segmentedControls["native.wish.tabs"]
        let unrealized = phases.buttons["未实现"]
        let realized = phases.buttons["已实现"]
        XCTAssertTrue(unrealized.waitForExistence(timeout: 8))
        XCTAssertTrue(unrealized.isSelected)
        XCTAssertTrue(app.buttons["native.wish.balance"].exists)
        XCTAssertFalse(app.staticTexts["预算结余形成，非真实资金。"].exists)
        app.buttons["native.wish.layout"].tap()
        let wish = wishRow("一副新耳机", in: app)
        XCTAssertTrue(wish.waitForExistence(timeout: 5))
        let wishID = wish.identifier
        wish.tap()
        let expanded = app.descendants(matching: .any)["native.wish.expanded"].firstMatch
        XCTAssertTrue(expanded.waitForExistence(timeout: 5))
        expanded.descendants(matching: .any)[wishID].firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.16, dy: 0.45)).tap()
        let redeem = expanded.buttons["native.wish.redeem"].firstMatch
        let redeemable = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == true AND enabled == true"), object: redeem)
        XCTAssertEqual(XCTWaiter.wait(for: [redeemable], timeout: 5), .completed)
        redeem.tap()
        let amount = app.textFields["wallet.wishes.actual"]
        XCTAssertTrue(amount.waitForExistence(timeout: 5))
        replace(amount, with: "100")
        let realPurchase = app.switches["wallet.wishes.purchaseConfirmed"]
        reveal(realPurchase, in: app)
        realPurchase.tap()
        let confirm = app.buttons["wallet.wishes.confirm"]
        reveal(confirm, in: app)
        confirm.tap()
        let saved = app.descendants(matching: .any)["native.outcome.result"].firstMatch
        XCTAssertTrue(saved.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["native.outcome.skip"].waitForNonExistence(timeout: 8))
        let viewRealized = app.buttons["查看已实现"]
        XCTAssertTrue(viewRealized.waitForExistence(timeout: 5))
        XCTAssertTrue(viewRealized.isHittable)
        viewRealized.tap()
        XCTAssertTrue(expanded.waitForNonExistence(timeout: 5))
        XCTAssertTrue(realized.isSelected)
        XCTAssertTrue(wish.waitForExistence(timeout: 5))
        XCTAssertTrue((wish.value as? String)?.contains("¥100") == true)
        unrealized.tap()
        XCTAssertTrue(wish.waitForNonExistence(timeout: 5))
        realized.tap()
        XCTAssertTrue(wish.waitForExistence(timeout: 5))
        wish.tap()
        XCTAssertTrue(expanded.waitForExistence(timeout: 5))
        XCTAssertTrue(expanded.staticTexts["¥100"].exists)
        XCTAssertFalse(expanded.buttons["native.wish.redeem"].exists)
        attach(app, "completed-wish-expanded-detail")
        expanded.buttons["关闭"].tap()
        XCTAssertTrue(app.buttons["wallet.header.create"].isHittable)
        attach(app, "completed-wish-realized-section")
        app.buttons["wallet.header.create"].tap()
        XCTAssertTrue(app.textFields["wallet.wishes.name"].waitForExistence(timeout: 5))
    }

    func testEmptyWishOffersCreationFromEmptyStateAndHeader() {
        let app = launch("wishes-empty")
        let add = app.buttons["wallet.wishes.empty.add"]
        XCTAssertTrue(add.waitForExistence(timeout: 8))
        XCTAssertTrue(add.isHittable)
        XCTAssertEqual(app.buttons.matching(identifier: "wallet.wishes.empty.add").count, 1)
        XCTAssertTrue(app.buttons["wallet.header.create"].exists)
        XCTAssertFalse(app.staticTexts["留一个想实现的心愿"].exists)
        XCTAssertFalse(app.staticTexts["预算结余形成，非真实资金。"].exists)
        add.tap()
        let name = app.textFields["wallet.wishes.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        app.navigationBars["添加心愿"].buttons["关闭"].tap()
        XCTAssertTrue(name.waitForNonExistence(timeout: 5))
        app.buttons["wallet.header.create"].tap()
        XCTAssertTrue(name.waitForExistence(timeout: 5))
    }

    func testWishPurchaseKeepsCurrencyQuoteAndExplicitConfirmation() {
        let app = launch("wishes")
        let layout = app.buttons["native.wish.layout"]
        XCTAssertTrue(layout.waitForExistence(timeout: 8))
        layout.tap()
        let wish = wishRow("一副新耳机", in: app)
        XCTAssertTrue(wish.waitForExistence(timeout: 5))
        let wishID = wish.identifier
        wish.tap()
        let expanded = app.descendants(matching: .any)["native.wish.expanded"].firstMatch
        XCTAssertTrue(expanded.waitForExistence(timeout: 5))
        let card = expanded.descendants(matching: .any)[wishID].firstMatch
        card.coordinate(withNormalizedOffset: CGVector(dx: 0.16, dy: 0.45)).tap()
        let redeem = expanded.buttons["native.wish.redeem"].firstMatch
        let redeemable = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == true AND enabled == true"), object: redeem)
        XCTAssertEqual(XCTWaiter.wait(for: [redeemable], timeout: 5), .completed)
        redeem.tap()

        let amount = app.textFields["wallet.wishes.actual"]
        let currency = app.buttons["wallet.wishes.purchaseCurrency"]
        XCTAssertTrue(amount.waitForExistence(timeout: 8))
        XCTAssertEqual(currency.value as? String, "CNY")
        replace(amount, with: "10")
        finishKeyboard(in: app)
        currency.tap()
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "USD")).firstMatch.tap()
        XCTAssertEqual(currency.value as? String, "USD")

        let confirm = app.buttons["wallet.wishes.confirm"]
        let provenance = app.staticTexts["wallet.exchange.provenance.input"]
        reveal(provenance, in: app)
        XCTAssertTrue(provenance.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["wallet.exchange.provenance.time"].exists)
        XCTAssertFalse(confirm.isEnabled)
        let rate = app.textFields["wallet.exchange.rate"]
        reveal(rate, in: app)
        replace(rate, with: "7")
        finishKeyboard(in: app)
        XCTAssertEqual(rate.value as? String, "7")

        let balanceAfter = app.descendants(matching: .any)["wallet.wishes.balanceAfter"]
        XCTAssertTrue(balanceAfter.waitForExistence(timeout: 5))
        XCTAssertTrue(balanceAfter.label.contains("790"), balanceAfter.label)
        XCTAssertTrue(app.descendants(matching: .any)["wallet.exchange.walletChange"].label.contains("70"))
        XCTAssertTrue(provenance.exists, "Wish conversion must retain its only source and time.")
        XCTAssertFalse(confirm.isEnabled, "A valid conversion cannot replace real-purchase consent.")
        let purchased = app.switches["wallet.wishes.purchaseConfirmed"]
        let form = app.scrollViews.containing(.switch, identifier: "wallet.wishes.purchaseConfirmed").firstMatch
        revealFormControl(purchased, in: form, below: app.navigationBars["兑现心愿"], above: confirm, app: app)
        XCTAssertEqual(purchased.value as? String, "0")
        purchased.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
        XCTAssertEqual(purchased.value as? String, "1", app.debugDescription)
        XCTAssertTrue(confirm.isEnabled)
        XCTAssertTrue(app.descendants(matching: .any)["wallet.exchange.walletChange"].exists)
        attach(app, "wish-usd-purchase-cny-impact")
        confirm.tap()

        let result = app.descendants(matching: .any)["native.outcome.result"].firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["native.outcome.skip"].waitForNonExistence(timeout: 8))
        let savedActual = result.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS '$' AND label CONTAINS '10'")).firstMatch
        XCTAssertTrue(savedActual.exists, "The saved original amount must remain 10 USD.")
        app.buttons["查看已实现"].tap()
        XCTAssertTrue(result.waitForNonExistence(timeout: 5))
        XCTAssertTrue(expanded.waitForNonExistence(timeout: 5))
        let realized = app.segmentedControls["native.wish.tabs"].buttons["已实现"]
        let selectedRealized = XCTNSPredicateExpectation(predicate: NSPredicate(format: "selected == true"), object: realized)
        XCTAssertEqual(XCTWaiter.wait(for: [selectedRealized], timeout: 5), .completed)
        let wallet = app.buttons["native.wish.balance"]
        XCTAssertTrue(wallet.waitForExistence(timeout: 5))
        wallet.tap()
        let walletAmount = app.staticTexts["wallet.wishes.balance.detail"]
        XCTAssertTrue(walletAmount.waitForExistence(timeout: 5))
        XCTAssertEqual(walletAmount.value as? String, "¥790")
        attach(app, "wish-original-usd-amount-saved")
    }

    func testMonthlyAmountPairsStayCompleteAtLargeEnglishText() {
        let app = launch("r34-home", english: true, accessibilityText: true)
        let card = app.descendants(matching: .any)["wallet.home.card"].firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 8))
        card.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.3)).tap()
        let edit = app.buttons["wallet.budget.limit.edit"]
        XCTAssertTrue(edit.waitForExistence(timeout: 5))
        reveal(edit, in: app)
        edit.tap()
        let amount = app.textFields["wallet.budget.edit.amount"]
        XCTAssertTrue(amount.waitForExistence(timeout: 5))
        replace(amount, with: "1600.25")
        app.buttons["wallet.budget.edit.preview"].tap()

        let newLimit = app.descendants(matching: .any)["wallet.budget.edit.newRecurringAmount"]
        reveal(newLimit, in: app)
        XCTAssertTrue(newLimit.waitForExistence(timeout: 5))
        XCTAssertTrue(newLimit.label.contains("This period and future periods"), newLimit.label)
        XCTAssertTrue(newLimit.label.contains("1,600.25"), newLimit.label)
        XCTAssertEqual(app.descendants(matching: .any).matching(identifier: "wallet.budget.edit.newRecurringAmount").count, 1)
        XCTAssertTrue(app.descendants(matching: .any)["wallet.budget.edit.oldAmount"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["wallet.budget.edit.remainingBefore"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["wallet.budget.edit.remainingAfter"].exists)
        XCTAssertTrue(app.staticTexts["Confirmed overrun"].exists)
        XCTAssertTrue(app.staticTexts["Possible additional overrun (pending)"].exists)
        reveal(newLimit, in: app)
        attach(app, "monthly-common-limit-large-english")
        let remainingAfter = app.descendants(matching: .any)["wallet.budget.edit.remainingAfter"]
        reveal(remainingAfter, in: app)
        attach(app, "monthly-paired-remaining-large-english")
        let back = app.buttons["wallet.budget.edit.back"]
        reveal(back, in: app)
        attach(app, "monthly-actions-large-english")
        back.tap()
        XCTAssertEqual(amount.value as? String, "1600.25")
        app.buttons["wallet.budget.edit.cancel"].tap()
    }

    func testSettlementQuoteProvenanceAndConfirmedWalletCredit() {
        let app = launch("settlement-fx")
        // The preview shortcut follows the pending period and empties when it settles.
        // Open the seeded card's normal drawer to exercise the saved result and return.
        let navigation = app.navigationBars["检查并结算"]
        let previewClose = navigation.buttons["关闭"]
        XCTAssertTrue(previewClose.waitForExistence(timeout: 8))
        previewClose.tap()
        XCTAssertTrue(navigation.waitForNonExistence(timeout: 5))
        let trip = app.staticTexts["周末旅行"].firstMatch
        XCTAssertTrue(trip.waitForExistence(timeout: 5))
        trip.tap()
        let settle = app.buttons["wallet.budget.settlement"]
        XCTAssertTrue(settle.waitForExistence(timeout: 8))
        if !settle.isHittable { app.scrollViews.firstMatch.swipeUp(velocity: .slow) }
        settle.tap()

        let inputSource = app.staticTexts["wallet.exchange.provenance.input"]
        let previewSource = app.staticTexts["wallet.exchange.provenance.preview"]
        XCTAssertTrue(inputSource.waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["wallet.exchange.provenance.time"].exists)
        XCTAssertFalse(previewSource.exists)
        let rate = app.textFields["wallet.exchange.rate"]
        let accept = app.buttons["wallet.settlement.acceptData"]
        let confirm = app.buttons["wallet.settlement.confirm"]
        let form = app.scrollViews.containing(.textField, identifier: "wallet.exchange.rate").firstMatch
        revealFormControl(rate, in: form, below: navigation, above: accept, app: app)
        attach(app, "settlement-fx-source-without-preview")
        replace(rate, with: "7")
        XCTAssertTrue(previewSource.waitForExistence(timeout: 5))
        XCTAssertFalse(inputSource.exists)
        XCTAssertFalse(app.staticTexts["wallet.exchange.provenance.time"].exists)
        revealFormControl(previewSource, in: form, below: navigation, above: accept, app: app)
        attach(app, "settlement-fx-single-source-with-preview")

        revealFormControl(rate, in: form, below: navigation, above: accept, app: app)
        replace(rate, with: "")
        XCTAssertTrue(inputSource.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["wallet.exchange.provenance.time"].exists)
        XCTAssertFalse(previewSource.exists)
        XCTAssertFalse(confirm.isEnabled)

        reveal(accept, in: app)
        accept.tap()
        XCTAssertFalse(confirm.isEnabled, "Acknowledging incomplete data cannot substitute for a valid quote.")
        revealFormControl(rate, in: form, below: navigation, above: accept, app: app)
        replace(rate, with: "7")
        XCTAssertTrue(previewSource.waitForExistence(timeout: 5))
        XCTAssertFalse(inputSource.exists)
        reveal(accept, in: app)
        XCTAssertFalse(confirm.isEnabled, "After changing the quote the user must acknowledge the revised review.")
        accept.tap()
        XCTAssertTrue(confirm.isEnabled)
        confirm.tap()

        let result = app.descendants(matching: .any)["native.outcome.result"].firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["native.outcome.skip"].waitForNonExistence(timeout: 8))
        let amount = result.staticTexts.matching(NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@", "结余", "+US$75")).firstMatch
        XCTAssertTrue(amount.exists)
        let movement = result.staticTexts.matching(NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@", "转入心愿余额", "+¥525")).firstMatch
        XCTAssertTrue(movement.exists)
        let balance = result.descendants(matching: .any)["native.outcome.wallet"].firstMatch
        XCTAssertTrue(balance.label.hasSuffix("¥1,385"))
        attach(app, "settlement-fx-saved-result")
        app.buttons["回到预算"].tap()
        XCTAssertTrue(result.waitForNonExistence(timeout: 5))
        let detailClose = app.buttons["wallet.budget.detail.close"]
        if detailClose.exists {
            detailClose.tap()
            XCTAssertTrue(detailClose.waitForNonExistence(timeout: 5))
        }

        let nativeWishTab = app.tabBars.buttons["心愿"].firstMatch
        let wishTab = nativeWishTab.exists ? nativeWishTab : app.buttons["wallet.tab.wishes"].firstMatch
        XCTAssertTrue(wishTab.waitForExistence(timeout: 5))
        wishTab.tap()
        let wallet = app.buttons["native.wish.balance"]
        XCTAssertTrue(wallet.waitForExistence(timeout: 5))
        wallet.tap()
        let savedBalance = app.staticTexts["wallet.wishes.balance.detail"]
        XCTAssertTrue(savedBalance.waitForExistence(timeout: 5))
        XCTAssertEqual(savedBalance.value as? String, "¥1,385")
        let savedCredit = app.buttons.matching(NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@", "结余", "525")).firstMatch
        reveal(savedCredit, in: app)
        savedCredit.tap()
        let entry = app.descendants(matching: .any)["wallet.wishes.entry.detail"].firstMatch
        XCTAssertTrue(entry.waitForExistence(timeout: 5))
        XCTAssertEqual(entry.descendants(matching: .any)["wallet.wishes.entry.amount"].firstMatch.value as? String, "¥525")
        attach(app, "settlement-fx-wallet-credit")
    }

    private func launch(_ screen: String, english: Bool = false, accessibilityText: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-design-preview", "-design-screen", screen, "-AppleLanguages", english ? "(en)" : "(zh-Hans)", "-AppleLocale", english ? "en_US" : "zh_CN"]
        if accessibilityText { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] }
        app.launch()
        return app
    }

    private func wishRow(_ title: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label == %@", "native.wish.card.", title)).firstMatch
    }

    private func replace(_ field: XCUIElement, with value: String) {
        field.tap()
        field.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
        let current = field.value as? String ?? ""
        let count = current == field.placeholderValue ? 0 : current.count
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: count) + value)
    }

    private func finishKeyboard(in app: XCUIApplication) {
        let done = app.buttons["完成输入"].firstMatch
        XCTAssertTrue(done.waitForExistence(timeout: 5), app.debugDescription)
        done.tap()
        XCTAssertTrue(done.waitForNonExistence(timeout: 5), "Finishing input must dismiss the keyboard toolbar.")
    }

    private func reveal(_ element: XCUIElement, in app: XCUIApplication, upwards: Bool = true) {
        for _ in 0..<8 {
            if element.isHittable { break }
            let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: upwards ? 0.38 : 0.18))
            let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: upwards ? 0.18 : 0.38))
            start.press(forDuration: 0.05, thenDragTo: end)
        }
        XCTAssertTrue(element.isHittable, app.debugDescription)
    }

    private func revealFormControl(
        _ element: XCUIElement, in form: XCUIElement, below navigation: XCUIElement,
        above footer: XCUIElement, app: XCUIApplication
    ) {
        XCTAssertTrue(form.waitForExistence(timeout: 5))
        for _ in 0..<8 {
            let bounds = form.frame.intersection(app.frame)
            let top = max(bounds.minY, navigation.frame.maxY) + 12
            let bottom = min(bounds.maxY, footer.frame.minY) - 12
            let hitY = element.frame.midY
            if element.isHittable && hitY >= top && hitY <= bottom { return }
            guard bottom > top + 40 else { break }
            let center = form.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0))
            let nearTop = center.withOffset(CGVector(dx: 0, dy: top - form.frame.minY + 12))
            let nearBottom = center.withOffset(CGVector(dx: 0, dy: bottom - form.frame.minY - 12))
            if hitY > bottom {
                nearBottom.press(forDuration: 0.05, thenDragTo: nearTop)
            } else {
                nearTop.press(forDuration: 0.05, thenDragTo: nearBottom)
            }
        }
        XCTFail("Could not scroll \(element.identifier) between the navigation bar and fixed actions.\n\(app.debugDescription)")
    }

    private func attach(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
