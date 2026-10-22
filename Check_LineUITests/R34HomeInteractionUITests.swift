import XCTest

/// Exercises the native gesture/state contract against an isolated, synthetic ledger.
/// Screenshots document geometry; the R34 comparison recording remains a separate
/// visual acceptance check, especially for the contact, liquid, and light timing.
@MainActor final class R34HomeInteractionUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        if #available(iOS 27.0, *) { try XCUIDevice.shared.voiceOverService.disable() }
    }

    func testEjectionDisconnectsSummaryAndTapReinsertsBeforeOpeningDetails() {
        let app = launchBudgets()
        let card = element("wallet.home.card", in: app)
        let used = app.buttons["native.home.summary.used"]
        let period = app.buttons["native.home.summary.period"]
        XCTAssertTrue(card.waitForExistence(timeout: 10), app.debugDescription)
        XCTAssertTrue(used.waitForExistence(timeout: 5), app.debugDescription)
        waitForValue(card, containing: "已插入")
        XCTAssertTrue(used.isEnabled)
        XCTAssertTrue(period.isEnabled)

        // Start away from the card's add button. The same card and ledger remain selected.
        let cardName = "日常生活"
        XCTAssertTrue(card.staticTexts[cardName].exists)
        card.coordinate(withNormalizedOffset: CGVector(dx: 0.72, dy: 0.24)).press(forDuration: 0.6)
        waitForValue(card, containing: "已拔出")
        XCTAssertTrue(card.staticTexts[cardName].exists)
        XCTAssertFalse(used.isEnabled, "An unplugged card must not offer stale summary navigation.")
        XCTAssertFalse(period.isEnabled, "The period summary must disconnect with the used amount.")
        attach(app, "r34-ejected-disconnected-summary")

        card.coordinate(withNormalizedOffset: CGVector(dx: 0.72, dy: 0.24)).tap()
        waitForValue(card, containing: "已插入")
        waitUntilEnabled(used)
        XCTAssertTrue(period.isEnabled)
        XCTAssertTrue(card.staticTexts[cardName].exists)
        XCTAssertFalse(app.buttons["wallet.budget.settlement"].exists,
                       "The reinsertion tap must not also open budget details.")
        attach(app, "r34-reinserted-same-budget")

        card.coordinate(withNormalizedOffset: CGVector(dx: 0.72, dy: 0.24)).tap()
        XCTAssertTrue(app.buttons["wallet.budget.settlement"].waitForExistence(timeout: 5), app.debugDescription)
    }

    func testHorizontalThrowChangesRealBudgetAndReverseSwipeRestoresIt() {
        let app = launchBudgets()
        let card = element("wallet.home.card", in: app)
        XCTAssertTrue(card.waitForExistence(timeout: 10), app.debugDescription)
        waitForValue(card, containing: "已插入")
        XCTAssertTrue(card.staticTexts["日常生活"].exists)
        attach(app, "r34-stack-daily-selected")

        drag(card, from: CGVector(dx: 0.8, dy: 0.28), by: CGVector(dx: -190, dy: 0))
        XCTAssertTrue(card.staticTexts["周末旅行"].waitForExistence(timeout: 5), app.debugDescription)
        waitForValue(card, containing: "已插入")
        XCTAssertTrue(app.buttons["native.home.summary.used"].isEnabled)
        attach(app, "r34-stack-trip-promoted")

        drag(card, from: CGVector(dx: 0.2, dy: 0.28), by: CGVector(dx: 190, dy: 0))
        XCTAssertTrue(card.staticTexts["日常生活"].waitForExistence(timeout: 5), app.debugDescription)
        waitForValue(card, containing: "已插入")
        attach(app, "r34-stack-reverse-restored")
    }

    func testShortHolderDragReturnsAndRecordsControlsFollowRetreatedHolder() {
        let app = launchBudgets()
        let holder = element("native.holder.surface", in: app)
        let card = element("wallet.home.card", in: app)
        let records = element("native.budget.records", in: app)
        XCTAssertTrue(holder.waitForExistence(timeout: 10), app.debugDescription)
        waitForValue(holder, containing: "已就绪")
        let originalCardFrame = card.frame

        // A real short drag must not be promoted by release velocity into another layer.
        drag(holder, from: CGVector(dx: 0.025, dy: 0.48), by: CGVector(dx: 0, dy: -22))
        waitForValue(holder, containing: "已就绪")
        XCTAssertFalse(records.exists)
        XCTAssertFalse(element("native.budget.library", in: app).exists)
        XCTAssertEqual(card.frame.minY, originalCardFrame.minY, accuracy: 3)
        XCTAssertEqual(card.frame.height, originalCardFrame.height, accuracy: 3)

        app.buttons["native.holder.up"].tap()
        XCTAssertTrue(records.waitForExistence(timeout: 5), app.debugDescription)
        waitForValue(holder, containing: "已就绪")
        XCTAssertGreaterThan(card.frame.width / max(card.frame.height, 1), 3.5,
                             "The record layer needs a compact horizontal liquid window.")
        let down = app.buttons["native.holder.down"]
        XCTAssertTrue(down.isHittable)
        XCTAssertGreaterThanOrEqual(down.frame.midY, card.frame.maxY - 4)
        XCTAssertLessThanOrEqual(down.frame.midY, card.frame.maxY + 84,
                                 "The return control follows the compact window, not its former dashboard position.")
        XCTAssertFalse(app.buttons["native.holder.up"].isHittable,
                       "The records layer must not offer another upward layer transition.")

        holder.coordinate(withNormalizedOffset: CGVector(dx: 0.025, dy: 0.55)).tap()
        XCTAssertTrue(records.exists, "Tapping the drag surface must not return to the dashboard.")
        attach(app, "r34-records-window-holder-and-buttons")
        down.tap()
        XCTAssertTrue(records.waitForNonExistence(timeout: 5), app.debugDescription)
        waitForValue(card, containing: "已插入")
        XCTAssertEqual(card.frame.height, originalCardFrame.height, accuracy: 3)
        XCTAssertTrue(app.buttons["native.holder.up"].isHittable)
    }

    func testArcSideCardFocusesBeforeSelectingAndReturnSurfaceDoesNotRespondToTap() {
        let app = launchBudgets()
        app.buttons["native.holder.down"].tap()
        let library = element("native.budget.library", in: app)
        let layout = app.buttons["native.library.layout"]
        XCTAssertTrue(library.waitForExistence(timeout: 5), app.debugDescription)
        waitForValue(layout, containing: "弧线画廊")

        let sideCards = app.descendants(matching: .any).matching(NSPredicate(
            format: "identifier BEGINSWITH %@ AND value == %@",
            "native.library.card.", "点按聚焦"
        )).allElementsBoundByIndex
        guard let side = sideCards.first(where: { $0.isHittable }) else {
            XCTFail("The arc must show an actionable side card. \(app.debugDescription)")
            return
        }
        let sideID = side.identifier
        let selectedName = ["日常生活", "周末旅行", "学点新东西"].first { side.label.contains($0) }
        XCTAssertNotNil(selectedName, "The side card must expose its real budget title, not an anonymous backplate.")
        // The side card's accessibility bounding box extends behind the front
        // card. Tap the exposed strip, not that obscured bounding-box midpoint.
        let scene = element("native.library.surface", in: app)
        let centered = app.descendants(matching: .any).matching(NSPredicate(
            format: "identifier BEGINSWITH %@ AND value CONTAINS %@", "native.library.card.", "已聚焦"
        )).firstMatch
        let visibleSide = side.frame.intersection(scene.frame)
        let left = side.frame.midX < centered.frame.midX
        let minimumX = left ? visibleSide.minX + 5 : max(visibleSide.minX, centered.frame.maxX + 4)
        let maximumX = left ? min(visibleSide.maxX, centered.frame.minX - 4) : visibleSide.maxX - 5
        attach(app, "r34-arc-side-visible-edge-before-focus")
        let diagnostic = XCTAttachment(string: "side \(side.frame); centered \(centered.frame); scene \(scene.frame); library \(library.frame).")
        diagnostic.name = "r34-arc-viewport-geometry"; diagnostic.lifetime = .keepAlways; add(diagnostic)
        XCTAssertGreaterThan(maximumX - minimumX, 3, "The arc must leave a real exposed side-card selection target. side=\(side.frame) center=\(centered.frame) scene=\(scene.frame)")
        let point = CGPoint(x: (minimumX + maximumX) / 2,
                            y: min(visibleSide.maxY - 14, max(visibleSide.minY + 14, side.frame.midY)))
        attach(app, "r34-arc-side-visible-edge-before-focus")
        let touch = XCTAttachment(string: "Tap \(point); side \(side.frame); centered \(centered.frame); scene \(scene.frame).")
        touch.name = "r34-arc-visible-edge-touch-geometry"; touch.lifetime = .keepAlways; add(touch)
        app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: point.x, dy: point.y)).tap()
        XCTAssertTrue(library.exists, "A side-card tap focuses it; selecting requires the centered card.")
        let focused = app.descendants(matching: .any).matching(NSPredicate(
            format: "identifier == %@ AND value CONTAINS %@", sideID, "已聚焦"
        )).firstMatch
        XCTAssertTrue(focused.waitForExistence(timeout: 5), app.debugDescription)
        attach(app, "r34-arc-side-card-focused")

        let returnSurface = element("native.library.return", in: app)
        XCTAssertTrue(returnSurface.isHittable)
        returnSurface.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(library.exists, "The bottom grip is a drag target; a tap must not change layers.")

        focused.tap()
        XCTAssertTrue(library.waitForNonExistence(timeout: 5), app.debugDescription)
        let card = element("wallet.home.card", in: app)
        XCTAssertTrue(card.staticTexts[selectedName ?? ""].waitForExistence(timeout: 5), app.debugDescription)
        waitForValue(card, containing: "已插入")
    }

    func testDomeVerticalBrowsingStaysInLibraryAndOnlyBottomDragReturns() {
        let app = launchBudgets()
        app.buttons["native.holder.down"].tap()
        let library = element("native.budget.library", in: app)
        XCTAssertTrue(library.waitForExistence(timeout: 5), app.debugDescription)
        app.buttons["native.library.layout"].tap()
        let scene = element("native.library.surface", in: app)
        waitForValue(scene, containing: "球面卡库")

        let cards = app.descendants(matching: .any).matching(NSPredicate(
            format: "identifier BEGINSWITH %@", "native.library.card."
        )).allElementsBoundByIndex.filter { $0.isHittable }
        XCTAssertGreaterThanOrEqual(cards.count, 2, "The small three-card fixture must still use multiple rows.")
        if cards.count >= 2 {
            let rowCenters = cards.map { $0.frame.midY }
            XCTAssertGreaterThan((rowCenters.max() ?? 0) - (rowCenters.min() ?? 0), 30,
                                 "Sparse libraries must not flatten into a single horizontal row.")
        }
        attach(app, "r34-dome-small-library-multiple-rows")

        drag(scene, from: CGVector(dx: 0.58, dy: 0.62), by: CGVector(dx: 12, dy: -135))
        XCTAssertTrue(library.exists, "Browsing the sphere upward must not invoke the library return gesture.")
        waitForValue(scene, containing: "球面卡库")
        drag(scene, from: CGVector(dx: 0.58, dy: 0.35), by: CGVector(dx: -10, dy: 135))
        XCTAssertTrue(library.exists, "Browsing the sphere downward must not invoke the library return gesture.")
        attach(app, "r34-dome-after-two-axis-browsing")

        let grip = element("native.library.return", in: app)
        drag(grip, from: CGVector(dx: 0.5, dy: 0.3), by: CGVector(dx: 0, dy: 130))
        XCTAssertTrue(library.waitForNonExistence(timeout: 5), app.debugDescription)
        waitForValue(element("wallet.home.card", in: app), containing: "已插入")
        XCTAssertTrue(app.buttons["native.home.summary.used"].isEnabled)
        attach(app, "r34-library-bottom-return-restored")
    }

    private func launchBudgets() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-design-preview", "-design-screen", "r34-home", "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()
        XCTAssertTrue(app.buttons["wallet.home.capture"].waitForExistence(timeout: 10), app.debugDescription)
        return app
    }

    private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    private func drag(_ element: XCUIElement, from point: CGVector, by offset: CGVector) {
        let start = element.coordinate(withNormalizedOffset: point)
        start.press(forDuration: 0.06, thenDragTo: start.withOffset(offset))
    }

    private func waitForValue(_ element: XCUIElement, containing expected: String, file: StaticString = #filePath, line: UInt = #line) {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value CONTAINS %@", expected), object: element)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 6), .completed,
                       "Expected \(element.identifier) value to contain \(expected), got \(String(describing: element.value)).", file: file, line: line)
    }

    private func waitUntilEnabled(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: element)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 6), .completed, file: file, line: line)
    }

    private func attach(_ app: XCUIApplication, _ name: String) {
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = name
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }
}
