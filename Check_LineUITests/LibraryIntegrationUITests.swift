import XCTest

/// Runs the production views against an explicitly isolated in-memory ledger.
@MainActor final class LibraryIntegrationUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        if #available(iOS 27.0, *) { try XCUIDevice.shared.voiceOverService.disable() }
    }

    func testLightCompleteLibraryReturn() { completeFlow(theme: "light") }
    func testDarkCompleteLibraryReturn() { completeFlow(theme: "dark") }

    private func completeFlow(theme: String) {
        let app = launch(theme: theme)
        openLibrary(app)
        let initial = centered(app).label
        let orb = element("native.library.period", app)
        XCTAssertTrue(orb.exists)
        attach(app, "library-\(theme)-first")
        for _ in 0..<2 {
            let previous = centered(app).label
            drag(centered(app), dx: -225, dy: 0)
            XCTAssertNotEqual(centered(app).label, previous)
        }
        let focused = centered(app)
        let name = String(focused.label.split(separator: ",").first ?? "")
        XCTAssertNotEqual(focused.label, initial)
        XCTAssertEqual(orb.label, name)
        let frame = focused.frame
        drag(focused, dx: 0, dy: 34)
        XCTAssertTrue(element("native.budget.library", app).exists)
        XCTAssertEqual(centered(app).label, focused.label)
        XCTAssertEqual(centered(app).frame.midY, frame.midY, accuracy: 2)
        attach(app, "library-\(theme)-cancelled")
        drag(centered(app), dx: 0, dy: 115)
        XCTAssertTrue(element("native.budget.library", app).waitForNonExistence(timeout: 5))
        let home = element("wallet.home.card", app)
        XCTAssertTrue(home.staticTexts[name].waitForExistence(timeout: 5), app.debugDescription)
        waitForReady(app)
        attach(app, "library-\(theme)-landed")
        openLibrary(app)
        XCTAssertTrue(centered(app).label.hasPrefix(name + ","), "Reopening must focus the card actually selected on landing.")
        app.buttons["native.library.returnButton"].tap()
        XCTAssertTrue(element("native.budget.library", app).waitForNonExistence(timeout: 5))
        waitForReady(app)
    }

    func testCenteredTapAndSideFocus() {
        let app = launch()
        openLibrary(app)
        let center = centered(app)
        let scene = element("native.library.surface", app)
        let side = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@ AND value == %@", "native.library.edge.", "点按聚焦"))
            .allElementsBoundByIndex.first { $0.isHittable && $0.frame.midX > center.frame.midX }
        XCTAssertNotNil(side)
        guard let side else { return }
        let name = String(side.label.split(separator: ",").first ?? "")
        let rect = side.frame.intersection(scene.frame)
        app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: rect.maxX - 8, dy: rect.midY)).tap()
        XCTAssertTrue(element("native.budget.library", app).exists)
        XCTAssertTrue(centered(app).label.hasPrefix(name + ","))
        centered(app).tap()
        XCTAssertTrue(element("native.budget.library", app).waitForNonExistence(timeout: 5))
        XCTAssertTrue(element("wallet.home.card", app).staticTexts[name].exists)
    }

    func testSingleCardStaysCenteredAndReducedMotionKeepsPeriod() {
        let app = launch(screen: "limit-one-shot", reduced: true)
        openLibrary(app)
        let before = centered(app).frame
        XCTAssertTrue(element("native.library.period", app).exists)
        drag(centered(app), dx: -210, dy: 0)
        XCTAssertEqual(centered(app).frame.midX, before.midX, accuracy: 1)
        XCTAssertTrue(centered(app).isHittable)
        app.buttons["native.library.close"].tap()
        XCTAssertTrue(element("native.budget.library", app).waitForNonExistence(timeout: 5))
    }

    func testSearchAndSphereKeepTheirSelectionPaths() {
        let app = launch()
        openLibrary(app)
        app.buttons["native.library.layout"].tap()
        let scene = element("native.library.surface", app)
        drag(scene, dx: 0, dy: 100)
        XCTAssertTrue(element("native.budget.library", app).exists)
        drag(scene, dx: 0, dy: -100)
        XCTAssertTrue(element("native.budget.library", app).exists)
        app.buttons["native.library.search"].tap()
        let search = app.textFields["native.library.searchField"]
        search.tap(); search.typeText("周末")
        let result = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label CONTAINS %@", "native.library.card.", "周末旅行")).firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 5))
        result.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.25)).tap()
        XCTAssertTrue(element("native.budget.library", app).waitForNonExistence(timeout: 5))
        XCTAssertTrue(element("wallet.home.card", app).staticTexts["周末旅行"].exists)
    }

    func testBackgroundRetainsBrowsedCardWithoutSelectingIt() {
        let app = launch()
        openLibrary(app)
        drag(centered(app), dx: -225, dy: 0)
        let focus = centered(app).label
        XCUIDevice.shared.press(.home)
        app.activate()
        XCTAssertTrue(element("native.budget.library", app).waitForExistence(timeout: 5))
        XCTAssertEqual(centered(app).label, focus)
        app.buttons["native.library.returnButton"].tap()
        XCTAssertTrue(element("native.budget.library", app).waitForNonExistence(timeout: 5))
        XCTAssertTrue(element("wallet.home.card", app).staticTexts[String(focus.split(separator: ",").first ?? "")].exists)
    }

    func testEnglishLargeTextHasUsableCardAndReturn() {
        let app = launch(large: true)
        openLibrary(app)
        let card = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@", "native.library.card.")).firstMatch
        XCTAssertTrue(card.isHittable)
        XCTAssertGreaterThan(card.frame.minX, 10)
        XCTAssertLessThan(card.frame.maxX, app.frame.width - 10)
        XCTAssertTrue(app.buttons["native.library.returnButton"].isHittable)
        attach(app, "library-english-accessibility-text")
        card.tap()
        XCTAssertTrue(element("native.budget.library", app).waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.buttons["wallet.home.capture"].exists)
    }

    func testLandscapeUsesScrollableCardsWithoutClippingReturn() {
        let app = launch()
        XCUIDevice.shared.orientation = .landscapeLeft
        defer { XCUIDevice.shared.orientation = .portrait }
        openLibrary(app)
        let back = app.buttons["native.library.returnButton"]
        XCTAssertTrue(back.isHittable)
        XCTAssertLessThan(back.frame.maxY, app.frame.height)
        let cards = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@", "native.library.card."))
        XCTAssertGreaterThan(cards.count, 0)
        attach(app, "library-landscape-scrollable")
        back.tap()
        XCTAssertTrue(element("native.budget.library", app).waitForNonExistence(timeout: 5))
    }

    func testEmptyHomeKeepsCreationAvailable() {
        let app = XCUIApplication()
        app.launchArguments = ["-design-preview", "-design-screen", "budget-empty", "-AppleLanguages", "(zh-Hans)"]
        app.launch()
        XCTAssertTrue(app.buttons["wallet.header.create"].waitForExistence(timeout: 10))
        XCTAssertFalse(element("native.budget.library", app).exists)
        XCTAssertFalse(element("wallet.home.card", app).exists)
        app.buttons["wallet.header.create"].tap()
        XCTAssertTrue(app.textFields["wallet.composer.name"].waitForExistence(timeout: 5))
    }

    private func launch(screen: String = "r34-home", theme: String = "light", reduced: Bool = false, large: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-design-preview", "-design-screen", screen, "-checkline.appearance", theme,
                               "-AppleLanguages", large ? "(en)" : "(zh-Hans)", "-AppleLocale", large ? "en_US" : "zh_CN"]
        if reduced { app.launchArguments.append("-design-reduce-motion") }
        if large { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] }
        app.launch()
        XCTAssertTrue(app.buttons["native.holder.down"].waitForExistence(timeout: 10), app.debugDescription)
        return app
    }
    private func openLibrary(_ app: XCUIApplication) {
        app.buttons["native.holder.down"].tap()
        XCTAssertTrue(element("native.budget.library", app).waitForExistence(timeout: 5), app.debugDescription)
    }
    private func centered(_ app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@ AND value CONTAINS %@", "native.library.card.", "已聚焦")).firstMatch
    }
    private func drag(_ element: XCUIElement, dx: CGFloat, dy: CGFloat) {
        let start = element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: dx, dy: dy)), withVelocity: .slow, thenHoldForDuration: 0.05)
    }
    private func element(_ id: String, _ app: XCUIApplication) -> XCUIElement { app.descendants(matching: .any)[id].firstMatch }
    private func waitForReady(_ app: XCUIApplication) {
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "value CONTAINS %@", "已就绪"), object: element("native.holder.surface", app))], timeout: 5), .completed)
    }
    private func attach(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = name; shot.lifetime = .keepAlways; add(shot)
    }
}
