import XCTest

@MainActor
final class AmountReviewRefinementUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        if #available(iOS 27.0, *) { try XCUIDevice.shared.voiceOverService.disable() }
    }

    func testCompletedWishUsesStaticSectionAndKeepsDetailAndCreation() {
        let app = launch("wishes")
        let wish = app.staticTexts["一副新耳机"]
        XCTAssertTrue(wish.waitForExistence(timeout: 8))
        XCTAssertFalse(app.segmentedControls["wallet.wishes.filter"].exists)
        XCTAssertTrue(app.staticTexts["心愿余额"].exists)
        XCTAssertFalse(app.staticTexts["预算结余形成，非真实资金。"].exists)
        wish.tap()
        let purchased = app.buttons["已购买，去兑现"]
        reveal(purchased, in: app)
        purchased.tap()
        let amount = app.textFields["wallet.wishes.actual"]
        XCTAssertTrue(amount.waitForExistence(timeout: 5))
        replace(amount, with: "100")
        let realPurchase = app.switches["wallet.wishes.purchaseConfirmed"]
        reveal(realPurchase, in: app)
        realPurchase.tap()
        let confirm = app.buttons["wallet.wishes.confirm"]
        reveal(confirm, in: app)
        confirm.tap()
        XCTAssertTrue(app.staticTexts["这个心愿，实现了"].waitForExistence(timeout: 5))
        app.buttons["关闭"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["已实现"].waitForExistence(timeout: 5))
        XCTAssertFalse(purchased.exists)
        app.navigationBars.buttons.element(boundBy: 0).tap()

        let completed = app.staticTexts["wallet.wishes.completed.heading"]
        reveal(completed, in: app)
        XCTAssertEqual(completed.label, "已实现 · 1")
        XCTAssertFalse(app.buttons["已实现"].exists)
        reveal(wish, in: app)
        wish.tap()
        XCTAssertTrue(app.staticTexts["已实现"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["¥100"].exists)
        XCTAssertFalse(purchased.exists)
        attach(app, "completed-wish-static-detail")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.buttons["wallet.header.create"].isHittable)
        attach(app, "completed-wish-static-section")
        app.buttons["wallet.header.create"].tap()
        XCTAssertTrue(app.textFields["心愿名称"].waitForExistence(timeout: 5))
    }

    func testEmptyWishKeepsOneAddActionWithoutRepeatedHeadings() {
        let app = launch("wishes-empty")
        let add = app.buttons["wallet.wishes.empty.add"]
        XCTAssertTrue(add.waitForExistence(timeout: 8))
        XCTAssertTrue(add.isHittable)
        XCTAssertFalse(app.buttons["wallet.header.create"].exists)
        XCTAssertFalse(app.staticTexts["留一个想实现的心愿"].exists)
        XCTAssertFalse(app.staticTexts["预算结余形成，非真实资金。"].exists)
        add.tap()
        XCTAssertTrue(app.textFields["心愿名称"].waitForExistence(timeout: 5))
    }

    func testWishPurchaseKeepsCurrencyQuoteAndExplicitConfirmation() {
        let app = launch("redemption")
        let amount = app.textFields["wallet.wishes.actual"]
        let currency = app.textFields["wallet.wishes.purchaseCurrency"]
        XCTAssertTrue(amount.waitForExistence(timeout: 8))
        XCTAssertEqual(currency.value as? String, "CNY")
        replace(amount, with: "10")
        replace(currency, with: "USD")
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

        let balanceAfter = app.descendants(matching: .any)["wallet.wishes.balanceAfter"]
        XCTAssertTrue(balanceAfter.waitForExistence(timeout: 5))
        XCTAssertTrue(balanceAfter.label.contains("790"), balanceAfter.label)
        XCTAssertTrue(app.descendants(matching: .any)["wallet.exchange.walletChange"].label.contains("70"))
        XCTAssertTrue(provenance.exists, "Wish conversion must retain its only source and time.")
        XCTAssertFalse(confirm.isEnabled, "A valid conversion cannot replace real-purchase consent.")
        let purchased = app.switches["wallet.wishes.purchaseConfirmed"]
        reveal(purchased, in: app)
        purchased.tap()
        reveal(confirm, in: app)
        XCTAssertTrue(confirm.isEnabled)
        XCTAssertTrue(app.staticTexts["仅扣减心愿钱包，不再扣普通预算卡。"].exists)
        attach(app, "wish-usd-purchase-cny-impact")
        confirm.tap()

        XCTAssertTrue(app.staticTexts["这个心愿，实现了"].waitForExistence(timeout: 5))
        let savedActual = app.staticTexts.matching(NSPredicate(format: "label CONTAINS '$' AND label CONTAINS '10'")).firstMatch
        XCTAssertTrue(savedActual.exists, "The saved original amount must remain 10 USD.")
        XCTAssertTrue(app.staticTexts["¥790"].exists)
        attach(app, "wish-original-usd-amount-saved")
    }

    func testMonthlyAmountPairsStayCompleteAtLargeEnglishText() {
        let app = launch("home", english: true, accessibilityText: true)
        let more = app.buttons["wallet.home.card.more"]
        XCTAssertTrue(more.waitForExistence(timeout: 8))
        reveal(more, in: app)
        more.tap()
        app.buttons["Adjust monthly limit"].tap()
        let amount = app.textFields["wallet.budget.edit.amount"]
        XCTAssertTrue(amount.waitForExistence(timeout: 5))
        replace(amount, with: "1600.25")
        app.buttons["wallet.budget.edit.preview"].tap()

        let newLimit = app.descendants(matching: .any)["wallet.budget.edit.newMonthlyAmount"]
        reveal(newLimit, in: app)
        XCTAssertTrue(newLimit.waitForExistence(timeout: 5))
        XCTAssertTrue(newLimit.label.contains("This and future months"), newLimit.label)
        XCTAssertTrue(newLimit.label.contains("1,600.25"), newLimit.label)
        XCTAssertEqual(app.descendants(matching: .any).matching(identifier: "wallet.budget.edit.newMonthlyAmount").count, 1)
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

    func testSettlementQuoteProvenanceRemainsVisibleWithoutDuplication() {
        let app = launch("settlement-fx")
        let inputSource = app.staticTexts["wallet.exchange.provenance.input"]
        let previewSource = app.staticTexts["wallet.exchange.provenance.preview"]
        XCTAssertTrue(inputSource.waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["wallet.exchange.provenance.time"].exists)
        XCTAssertFalse(previewSource.exists)
        let rate = app.textFields["wallet.exchange.rate"]
        reveal(rate, in: app)
        attach(app, "settlement-fx-source-without-preview")
        replace(rate, with: "7")
        XCTAssertTrue(previewSource.waitForExistence(timeout: 5))
        XCTAssertFalse(inputSource.exists)
        XCTAssertFalse(app.staticTexts["wallet.exchange.provenance.time"].exists)
        reveal(previewSource, in: app)
        attach(app, "settlement-fx-single-source-with-preview")

        reveal(rate, in: app, upwards: false)
        replace(rate, with: "")
        XCTAssertTrue(inputSource.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["wallet.exchange.provenance.time"].exists)
        XCTAssertFalse(previewSource.exists)
        XCTAssertFalse(app.buttons["wallet.settlement.confirm"].isEnabled)
    }

    private func launch(_ screen: String, english: Bool = false, accessibilityText: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-design-preview", "-design-screen", screen, "-AppleLanguages", english ? "(en)" : "(zh-Hans)", "-AppleLocale", english ? "en_US" : "zh_CN"]
        if accessibilityText { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] }
        app.launch()
        return app
    }

    private func replace(_ field: XCUIElement, with value: String) {
        field.tap()
        field.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
        let current = field.value as? String ?? ""
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count) + value)
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

    private func attach(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
