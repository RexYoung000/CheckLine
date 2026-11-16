import XCTest

/// Repeats the dated-card path that the original gallery demo did not exercise:
/// its complete flow changed focus twice before pulling an undated card home.
@MainActor final class LibraryStressUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        if #available(iOS 27.0, *) { try XCUIDevice.shared.voiceOverService.disable() }
    }

    func testDatedCardRepeatedPullsLight() { repeatDatedReturns(theme: "light") }
    func testDatedCardRepeatedPullsDark() { repeatDatedReturns(theme: "dark") }

    private func repeatDatedReturns(theme: String) {
        let app = launch(theme: theme)
        for iteration in 0..<8 {
            XCTContext.runActivity(named: "Dated card return \(iteration + 1) / \(theme)") { _ in
                openLibrary(app)
                let focus = centered(app)
                XCTAssertTrue(focus.label.hasPrefix("日常生活,"))
                let before = focus.frame
                for distance: CGFloat in [22, 43, 60] {
                    drag(focus, dx: iteration.isMultiple(of: 2) ? 3 : -3, dy: distance,
                         velocity: iteration.isMultiple(of: 2) ? .fast : .slow)
                    XCTAssertTrue(element("native.budget.library", app).exists)
                    XCTAssertEqual(centered(app).frame.midY, before.midY, accuracy: 2)
                }
                drag(centered(app), dx: iteration.isMultiple(of: 2) ? 8 : -8, dy: 118,
                     velocity: iteration.isMultiple(of: 2) ? .fast : .slow)
                assertReturned(app, name: "日常生活")
            }
        }
        // Existence alone does not prove that the returned page accepts input.
        app.buttons["native.holder.up"].tap()
        XCTAssertTrue(element("native.budget.records", app).waitForExistence(timeout: 5))
        app.buttons["native.holder.down"].tap()
        XCTAssertTrue(element("native.budget.records", app).waitForNonExistence(timeout: 5))
        attach(app, "dated-card-\(theme)-after-eight-returns")
    }

    func testAlternatingDatedAndUndatedFocusRemainsResponsive() {
        let app = launch(theme: "light")
        for iteration in 0..<6 {
            openLibrary(app)
            drag(centered(app), dx: iteration.isMultiple(of: 2) ? -220 : 220, dy: 0, velocity: .fast)
            let name = String(centered(app).label.split(separator: ",").first ?? "")
            XCTAssertFalse(name.isEmpty)
            drag(centered(app), dx: 0, dy: 35, velocity: .fast)
            drag(centered(app), dx: 0, dy: 120, velocity: .fast)
            assertReturned(app, name: name)
        }
        openLibrary(app)
        app.buttons["native.library.search"].tap()
        XCTAssertTrue(app.textFields["native.library.searchField"].waitForExistence(timeout: 5))
        app.buttons["native.library.close"].tap()
        XCTAssertTrue(element("native.budget.library", app).waitForNonExistence(timeout: 5))
    }

    func testCancelledPullThenBackgroundAndModeChangeCanStillReturn() {
        let app = launch(theme: "dark")
        for _ in 0..<3 {
            openLibrary(app)
            drag(centered(app), dx: 0, dy: 45, velocity: .fast)
            XCUIDevice.shared.press(.home)
            app.activate()
            XCTAssertTrue(element("native.budget.library", app).waitForExistence(timeout: 5))
            app.buttons["native.library.layout"].tap()
            drag(element("native.library.surface", app), dx: 30, dy: 100, velocity: .fast)
            XCTAssertTrue(element("native.budget.library", app).exists)
            app.buttons["native.library.layout"].tap()
            drag(centered(app), dx: 0, dy: 120, velocity: .fast)
            assertReturned(app, name: "日常生活")
        }
    }

    func testDatedSingleCardReducedMotionRepeatedReturn() {
        let app = launch(theme: "light", screen: "limit-weekly", reduced: true)
        for _ in 0..<5 {
            openLibrary(app)
            let name = String(centered(app).label.split(separator: ",").first ?? "")
            drag(centered(app), dx: 0, dy: 40, velocity: .fast)
            XCTAssertTrue(element("native.budget.library", app).exists)
            drag(centered(app), dx: 0, dy: 110, velocity: .fast)
            assertReturned(app, name: name)
        }
    }

    private func launch(theme: String, screen: String = "r34-home", reduced: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-design-preview", "-design-screen", screen,
                               "-checkline.appearance", theme, "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        if reduced { app.launchArguments.append("-design-reduce-motion") }
        app.launch()
        XCTAssertTrue(app.buttons["native.holder.down"].waitForExistence(timeout: 10))
        return app
    }

    private func openLibrary(_ app: XCUIApplication) {
        app.buttons["native.holder.down"].tap()
        XCTAssertTrue(element("native.budget.library", app).waitForExistence(timeout: 5))
        XCTAssertTrue(centered(app).waitForExistence(timeout: 5))
    }

    private func assertReturned(_ app: XCUIApplication, name: String) {
        XCTAssertTrue(element("native.budget.library", app).waitForNonExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(element("wallet.home.card", app).staticTexts[name].exists)
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value CONTAINS %@", "已就绪"),
                                             object: element("native.holder.surface", app))
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 5), .completed)
        XCTAssertTrue(app.buttons["native.holder.down"].isHittable)
    }

    private func drag(_ element: XCUIElement, dx: CGFloat, dy: CGFloat, velocity: XCUIGestureVelocity) {
        let start = element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.01, thenDragTo: start.withOffset(CGVector(dx: dx, dy: dy)),
                    withVelocity: velocity, thenHoldForDuration: 0)
    }

    private func centered(_ app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@ AND value CONTAINS %@",
                                                           "native.library.card.", "已聚焦")).firstMatch
    }
    private func element(_ id: String, _ app: XCUIApplication) -> XCUIElement { app.descendants(matching: .any)[id].firstMatch }
    private func attach(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
}
