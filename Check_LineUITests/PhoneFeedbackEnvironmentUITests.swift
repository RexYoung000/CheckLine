import XCTest

@MainActor
final class PhoneFeedbackEnvironmentUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        if #available(iOS 27.0, *) { try XCUIDevice.shared.voiceOverService.disable() }
    }

    func testLargeEnglishDarkWishReachesCurrencyAndSavesUSDWithoutChangingWallet() {
        let app = XCUIApplication()
        app.launchArguments = ["-design-preview", "-design-screen", "wishes-empty",
                               "-checkline.appearance", "dark", "-AppleLanguages", "(en)", "-AppleLocale", "en_US",
                               "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()

        let add = app.buttons["wallet.wishes.empty.add"]
        XCTAssertTrue(add.waitForExistence(timeout: 10), app.debugDescription)
        reveal(add, in: app.scrollViews.firstMatch, app: app)
        add.tap()
        let name = app.textFields["wallet.wishes.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        let form = app.scrollViews.containing(.textField, identifier: "wallet.wishes.name").firstMatch
        reveal(name, in: form, app: app)
        name.tap()
        name.typeText("Travel headphones")
        dismissKeyboard(app)

        let amount = app.textFields["wallet.wishes.estimate"]
        reveal(amount, in: form, app: app)
        amount.tap()
        amount.typeText("49.50")
        dismissKeyboard(app)
        attach(app, "phone-feedback-large-english-dark-wish-amount")

        let currency = app.buttons["wallet.wishes.currency"]
        reveal(currency, in: form, app: app)
        attach(app, "phone-feedback-large-english-dark-currency-reached")
        currency.tap()
        let usd = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "USD")).firstMatch
        XCTAssertTrue(usd.waitForExistence(timeout: 5), app.debugDescription)
        usd.tap()
        XCTAssertEqual(currency.value as? String, "USD")
        XCTAssertEqual(amount.value as? String, "49.50", "Scrolling and changing currency must retain the entered amount.")

        let save = app.buttons["wallet.wishes.create.save"]
        reveal(save, in: form, app: app)
        attach(app, "phone-feedback-large-english-dark-wish-ready-to-save")
        save.tap()
        XCTAssertTrue(save.waitForNonExistence(timeout: 5))
        let saved = app.staticTexts["Travel headphones"]
        XCTAssertTrue(saved.waitForExistence(timeout: 5), app.debugDescription)
        reveal(saved, in: app.scrollViews.firstMatch, app: app)
        saved.tap()
        XCTAssertTrue(app.navigationBars["Wish details"].waitForExistence(timeout: 5))
        let dollarEstimate = app.staticTexts.matching(NSPredicate(format: "label CONTAINS '$' AND label CONTAINS '49.5'")).firstMatch
        XCTAssertTrue(dollarEstimate.waitForExistence(timeout: 5), "The saved estimate must retain USD rather than use the CNY wallet currency.")
        reveal(dollarEstimate, in: app.scrollViews.firstMatch, app: app)
        attach(app, "phone-feedback-large-english-dark-saved-dollar-estimate")

        app.navigationBars["Wish details"].buttons.firstMatch.tap()
        let balance = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Wish balance")).firstMatch
        XCTAssertTrue(balance.waitForExistence(timeout: 5), app.debugDescription)
        reveal(balance, in: app.scrollViews.firstMatch, app: app)
        balance.tap()
        let walletAmount = app.staticTexts["wallet.wishes.balance.detail"]
        XCTAssertTrue(walletAmount.waitForExistence(timeout: 5))
        let expectedZero = Decimal.zero.formatted(.currency(code: "CNY").locale(Locale(identifier: "en_US")).precision(.fractionLength(0...2)))
        XCTAssertEqual(walletAmount.value as? String, expectedZero, "Creating the USD wish must leave the CNY wallet at zero.")
        attach(app, "phone-feedback-large-english-dark-wallet-still-zero")
    }

    private func dismissKeyboard(_ app: XCUIApplication) {
        let done = app.buttons["Done"].firstMatch
        if done.waitForExistence(timeout: 2), done.isHittable { done.tap() }
    }

    private func reveal(_ element: XCUIElement, in scrollView: XCUIElement, app: XCUIApplication) {
        XCTAssertTrue(scrollView.waitForExistence(timeout: 5), app.debugDescription)
        for _ in 0..<12 {
            let viewport = scrollView.frame.intersection(app.frame).insetBy(dx: 4, dy: 12)
            let frame = element.frame
            if element.isHittable && viewport.contains(CGPoint(x: frame.midX, y: frame.midY)) { return }
            if frame.minY < viewport.minY {
                scrollView.swipeDown(velocity: .slow)
            } else {
                scrollView.swipeUp(velocity: .slow)
            }
        }
        attach(app, "phone-feedback-large-text-unreachable-control")
        XCTFail("The user cannot reach \(element.identifier) by scrolling.\n\(app.debugDescription)")
    }

    private func attach(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
