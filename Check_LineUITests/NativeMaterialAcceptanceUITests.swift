import XCTest

/// Isolated launch fixtures only; screenshots never use the device ledger.
@MainActor final class NativeMaterialAcceptanceUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        if #available(iOS 27.0, *) { try XCUIDevice.shared.voiceOverService.disable() }
    }

    func testLightPreviewEntrances() { captureEntrances(theme: "light") }
    func testDarkPreviewEntrances() { captureEntrances(theme: "dark") }
    func testCollectionPreviewEntrances() {
        captureEntrances(theme: "light", selectedScreens: ["collection"])
        captureEntrances(theme: "dark", selectedScreens: ["collection"])
    }

    private func captureEntrances(theme: String, selectedScreens: [String]? = nil) {
        // Together these are the 21 accepted HTML entrances plus the collection state.
        let screens = selectedScreens ?? ["budgets", "records-layer", "library", "budget-detail", "records", "expense-detail",
                       "calendar", "history-review", "budget-info", "wishes", "wish-expanded", "wallet", "wallet-entry",
                       "record", "create-budget", "create-wish", "wish-cover", "agent", "settings", "settlement-fx", "redemption", "collection"]
        for screen in screens {
            let app = launch(screen, theme: theme)
            XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
            XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 10))
            if screen == "collection" {
                let selected = app.segmentedControls["native.wish.tabs"].buttons["已实现"]
                let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "selected == 1"), object: selected)
                XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 5), .completed)
                XCTAssertTrue(app.staticTexts["一本好书"].exists)
            }
            if screen == "wish-expanded" {
                let card = app.descendants(matching: .any)["native.wish.expanded"].firstMatch
                let expand = app.buttons["native.wish.expand"].firstMatch
                if !card.waitForExistence(timeout: 4), expand.isHittable { expand.tap() }
                XCTAssertTrue(card.waitForExistence(timeout: 5), app.debugDescription)
                let face = card.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@", "native.wish.card.")).firstMatch
                if (face.value as? String)?.contains("正面") == true { face.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.45)).tap() }
            }
            // Allow the existing entry transition to finish before recording its static material.
            let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in app.buttons.count > 0 }, object: nil)
            XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 8), .completed, "Missing controls at \(screen)")
            Thread.sleep(forTimeInterval: 0.7)
            attach(app, "material-\(theme)-\(screen)")
            app.terminate()
        }
    }

    func testReferenceRateApplyCancelAndActualPurchaseGate() {
        let app = launch("wishes-fx", theme: "dark")
        let front = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@", "native.wish.card.")).containing(.staticText, identifier: "一副新耳机").firstMatch
        XCTAssertTrue(front.waitForExistence(timeout: 10), app.debugDescription)
        let card = app.descendants(matching: .any)[front.identifier].firstMatch
        card.coordinate(withNormalizedOffset: CGVector(dx: 0.16, dy: 0.45)).tap()
        let checkRate = app.buttons["native.wish.checkRate"].firstMatch
        XCTAssertTrue(checkRate.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertFalse(card.buttons["native.wish.redeem"].isEnabled)
        checkRate.tap()
        let rate = app.textFields["wallet.exchange.rate"]
        XCTAssertTrue(rate.waitForExistence(timeout: 5))
        rate.tap(); rate.typeText("10")
        dismissKeyboard(app)
        app.buttons["native.wish.applyReference"].tap()
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        XCTAssertFalse(card.buttons["native.wish.redeem"].isEnabled)
        checkRate.tap()
        XCTAssertTrue(rate.waitForExistence(timeout: 5)); replace(rate, text: "7")
        dismissKeyboard(app)
        app.buttons["native.wish.cancelReference"].tap()
        checkRate.tap()
        XCTAssertTrue(rate.waitForExistence(timeout: 5))
        XCTAssertEqual(rate.value as? String, "10", "Cancel must retain the applied reference.")
        replace(rate, text: "7"); dismissKeyboard(app)
        attach(app, "material-reference-rate-review")
        app.buttons["native.wish.applyReference"].tap()
        let redeem = card.buttons["native.wish.redeem"]
        XCTAssertTrue(redeem.waitForExistence(timeout: 5))
        XCTAssertTrue(redeem.isEnabled)
        redeem.tap()
        let amount = app.textFields["wallet.wishes.actual"]
        XCTAssertTrue(amount.waitForExistence(timeout: 5))
        XCTAssertEqual(app.textFields["wallet.exchange.rate"].value as? String, "7")
        amount.tap(); amount.typeText("200"); dismissKeyboard(app)
        let consent = app.switches["wallet.wishes.purchaseConfirmed"]
        if !consent.isHittable { app.swipeUp() }
        consent.tap()
        XCTAssertFalse(app.buttons["wallet.wishes.confirm"].isEnabled, "A covered target does not authorize an unaffordable actual purchase.")
        attach(app, "material-reference-actual-over-balance")
    }

    func testSystemReduceTransparencyAndContrastRetainReadableCards() {
        let settings = XCUIApplication(bundleIdentifier: "com.apple.Preferences")
        settings.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        settings.launch()
        let accessibility = settings.buttons["com.apple.settings.accessibility"]
        for _ in 0..<5 { if accessibility.isHittable { break }; settings.swipeUp() }
        XCTAssertTrue(accessibility.waitForExistence(timeout: 8)); accessibility.tap()
        let display = settings.buttons["Display & Text Size"]
        XCTAssertTrue(display.waitForExistence(timeout: 8), settings.debugDescription); display.tap()
        let transparency = settings.switches["Reduce Transparency"]
        let contrast = settings.switches["Increase Contrast"]
        for _ in 0..<4 { if transparency.isHittable && contrast.isHittable { break }; settings.swipeUp() }
        XCTAssertTrue(transparency.waitForExistence(timeout: 5), settings.debugDescription)
        XCTAssertTrue(contrast.exists)
        let wasTransparent = transparency.value as? String == "1"
        let wasContrast = contrast.value as? String == "1"
        if !wasTransparent { transparency.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap() }
        if !wasContrast { contrast.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap() }
        XCTAssertEqual(transparency.value as? String, "1"); XCTAssertEqual(contrast.value as? String, "1")
        defer {
            settings.activate()
            XCTAssertTrue(settings.wait(for: .runningForeground, timeout: 5))
            Thread.sleep(forTimeInterval: 0.6)
            for (toggle, original) in [(transparency, wasTransparent), (contrast, wasContrast)] {
                let target = original ? "1" : "0"
                if toggle.value as? String != target { toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap() }
                let restored = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", target), object: toggle)
                XCTAssertEqual(XCTWaiter.wait(for: [restored], timeout: 5), .completed)
            }
        }
        for theme in ["light", "dark"] {
            let app = launch("wish-expanded", theme: theme)
            XCTAssertTrue(app.buttons["native.wish.redeem"].waitForExistence(timeout: 10), app.debugDescription)
            XCTAssertTrue(app.buttons["native.wish.redeem"].isEnabled)
            attach(app, "material-reduced-transparency-contrast-\(theme)")
            app.terminate()
        }
    }

    private func launch(_ screen: String, theme: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-design-preview", "-design-screen", screen, "-checkline.appearance", theme,
                               "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        // The library uses an accessibility grid when motion is reduced; capture
        // its accepted arc layout here, with its liquid thumbnails still static.
        if screen != "library" { app.launchArguments.append("-design-reduce-motion") }
        app.launch()
        return app
    }
    private func dismissKeyboard(_ app: XCUIApplication) {
        if app.buttons["完成输入"].firstMatch.exists { app.buttons["完成输入"].firstMatch.tap() }
    }
    private func replace(_ field: XCUIElement, text: String) {
        field.tap()
        let current = (field.value as? String) ?? ""
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count) + text)
    }
    private func attach(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
}
