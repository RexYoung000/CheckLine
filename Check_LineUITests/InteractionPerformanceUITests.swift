import XCTest

#if DEBUG
/// Hardware results describe the measured task window, including XCTest input
/// delivery/idle waits. They are not the wave's nominal animation duration.
@MainActor final class InteractionPerformanceUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        guard !UIAccessibility.isVoiceOverRunning else {
            throw XCTSkip("Direct-touch performance leaves the current VoiceOver setting unchanged.")
        }
        guard !UIAccessibility.isReduceMotionEnabled else {
            throw XCTSkip("Normal-motion performance requires system Reduce Motion off.")
        }
    }

    func testLibraryLightTaskPerformance() throws { try measureLibrary(theme: "light") }
    func testLibraryDarkTaskPerformance() throws { try measureLibrary(theme: "dark") }
    func testRecoveryWaveTaskPerformance() throws { try measureSettlement(screen: "settlement-recovery") }
    func testOverrunWaveTaskPerformance() throws { try measureSettlement(screen: "settlement-overrun") }

    private func measureLibrary(theme: String) throws {
        guard #available(iOS 26.0, *) else { throw XCTSkip("Hitch metric requires iOS 26.") }
        let app = application(screen: "r34-home", theme: theme)
        app.launch()
        XCTAssertTrue(app.buttons["native.holder.down"].waitForExistence(timeout: 10))
        let options = XCTMeasureOptions()
        options.iterationCount = 3
        measure(metrics: metrics(app), options: options) {
            app.buttons["native.holder.down"].tap()
            XCTAssertTrue(element("native.budget.library", app).waitForExistence(timeout: 5))
            for dx: CGFloat in [-220, 220] { drag(centered(app), dx: dx, dy: 0) }
            drag(centered(app), dx: 0, dy: 35)
            XCTAssertTrue(element("native.budget.library", app).exists)
            drag(centered(app), dx: 0, dy: 118)
            XCTAssertTrue(element("native.budget.library", app).waitForNonExistence(timeout: 5))
            XCTAssertTrue(app.buttons["native.holder.down"].isHittable)
        }
    }

    private func measureSettlement(screen: String) throws {
        guard #available(iOS 26.0, *) else { throw XCTSkip("Hitch metric requires iOS 26.") }
        let app = application(screen: screen, theme: "light")
        let options = XCTMeasureOptions()
        options.iterationCount = 3
        options.invocationOptions = [.manuallyStart, .manuallyStop]
        let capture = XCTOSSignpostMetric(subsystem: "Rex.CheckLine", category: "Settlement", name: "SettlementCapture")
        let save = XCTOSSignpostMetric(subsystem: "Rex.CheckLine", category: "Settlement", name: "SettlementSave")
        measure(metrics: metrics(app) + [capture, save], options: options) {
            // Each launch creates a separate in-memory ledger for the next save.
            app.launch()
            XCTAssertTrue(app.staticTexts["周末旅行"].firstMatch.waitForExistence(timeout: 10))
            app.staticTexts["周末旅行"].firstMatch.tap()
            let settle = app.buttons["wallet.budget.settlement"]
            XCTAssertTrue(settle.waitForExistence(timeout: 8))
            if !settle.isHittable { app.scrollViews.firstMatch.swipeUp(velocity: .slow) }
            settle.tap()
            let accept = app.buttons["wallet.settlement.acceptData"]
            XCTAssertTrue(accept.waitForExistence(timeout: 6))
            accept.tap()

            startMeasuring()
            app.buttons["wallet.settlement.confirm"].tap()
            XCTAssertTrue(element("native.outcome.result", app).waitForExistence(timeout: 5))
            XCTAssertTrue(app.buttons["native.outcome.skip"].waitForNonExistence(timeout: 6))
            // Includes the settled result after the overlay has actually left.
            Thread.sleep(forTimeInterval: 0.35)
            stopMeasuring()
            XCTAssertTrue(app.buttons["回到预算"].isHittable)
        }
    }

    @available(iOS 26.0, *)
    private func metrics(_ app: XCUIApplication) -> [any XCTMetric] {
        [XCTClockMetric(), XCTCPUMetric(application: app), XCTMemoryMetric(application: app), XCTHitchMetric(application: app)]
    }

    private func application(screen: String, theme: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-design-preview", "-design-screen", screen, "-checkline.appearance", theme,
                               "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        return app
    }
    private func drag(_ element: XCUIElement, dx: CGFloat, dy: CGFloat) {
        let start = element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.01, thenDragTo: start.withOffset(CGVector(dx: dx, dy: dy)),
                    withVelocity: .fast, thenHoldForDuration: 0)
    }
    private func centered(_ app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@ AND value CONTAINS %@",
                                                           "native.library.card.", "已聚焦")).firstMatch
    }
    private func element(_ id: String, _ app: XCUIApplication) -> XCUIElement { app.descendants(matching: .any)[id].firstMatch }
}
#endif
