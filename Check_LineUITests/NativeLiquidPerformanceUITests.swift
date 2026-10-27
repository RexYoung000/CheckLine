import XCTest

#if DEBUG
/// Measures the CPU Canvas draw interval in the isolated local ledger.
/// This does not measure GPU completion, display FPS, battery, or device acceptance.
@MainActor final class NativeLiquidPerformanceUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        if #available(iOS 27.0, *) { try XCUIDevice.shared.voiceOverService.disable() }
        guard !UIAccessibility.isReduceMotionEnabled else {
            throw XCTSkip("Liquid performance sampling requires the system Reduce Motion setting to be off.")
        }
    }

    func testVisibleLiquidDrawDurationForThreeSeconds() {
        let app = launchBudget()
        XCTAssertTrue(app.buttons["wallet.home.capture"].waitForExistence(timeout: 10), app.debugDescription)
        Thread.sleep(forTimeInterval: 1)
        let options = XCTMeasureOptions()
        options.iterationCount = 1
        measure(metrics: [liquidMetric()], options: options) {
            Thread.sleep(forTimeInterval: 3)
        }
        attach(app, "liquid-visible-normal-motion-after-three-second-sample")
    }

    func testAgentCoverPausesLiquidDrawIntervalsAndReturnResumes() throws {
        let app = launchBudget(metricsProbe: true)
        XCTAssertTrue(app.buttons["wallet.home.capture"].waitForExistence(timeout: 10), app.debugDescription)
        Thread.sleep(forTimeInterval: 1)
        let visible = try sampleCounts("visible-before-agent", app: app)
        XCTAssertGreaterThan(visible.end.frames, visible.start.frames, "A visible budget must draw new frames.")
        XCTAssertGreaterThan(visible.end.running, 0)

        let nativeAgent = app.tabBars.buttons.matching(NSPredicate(format: "label CONTAINS %@", "小朵")).firstMatch
        let agent = nativeAgent.exists ? nativeAgent : app.buttons["wallet.agent.avatar"].firstMatch
        XCTAssertTrue(agent.waitForExistence(timeout: 5), app.debugDescription)
        agent.tap()
        let close = app.buttons["wallet.agent.close"].firstMatch
        XCTAssertTrue(close.waitForExistence(timeout: 5), app.debugDescription)
        Thread.sleep(forTimeInterval: 1)
        let covered = try sampleCounts("agent-covered", app: app)
        XCTAssertEqual(covered.start.running, 0)
        XCTAssertEqual(covered.end.running, 0)
        XCTAssertEqual(covered.start.frames, covered.end.frames, "Covered liquid must not submit new Canvas draws after the Agent settles.")
        XCTAssertTrue(close.isHittable)

        close.tap()
        XCTAssertTrue(close.waitForNonExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(app.buttons["wallet.home.capture"].waitForExistence(timeout: 5), app.debugDescription)
        Thread.sleep(forTimeInterval: 1)
        let resumed = try sampleCounts("visible-after-agent", app: app)
        XCTAssertGreaterThan(resumed.end.frames, resumed.start.frames, "Returning to the budget must resume liquid draws.")
        XCTAssertGreaterThan(resumed.end.running, 0)
    }

    private func liquidMetric() -> XCTOSSignpostMetric {
        XCTOSSignpostMetric(subsystem: "Rex.CheckLine", category: "Liquid", name: "LiquidFrame")
    }

    private struct DrawSnapshot: CustomStringConvertible {
        let frames: UInt64
        let running: Int
        var description: String { "frames=\(frames);running=\(running)" }
    }

    private func snapshot(_ app: XCUIApplication) throws -> DrawSnapshot {
        let probe = app.descendants(matching: .any)["debug.liquid.metrics"].firstMatch
        XCTAssertTrue(probe.waitForExistence(timeout: 5), "The explicit DEBUG metrics probe must be available in the current page or sheet.")
        let value = try XCTUnwrap(probe.value as? String)
        let fields = Dictionary(uniqueKeysWithValues: value.split(separator: ";").compactMap { part -> (String, String)? in
            let pair = part.split(separator: "=", maxSplits: 1)
            guard pair.count == 2 else { return nil }
            return (String(pair[0]), String(pair[1]))
        })
        let frames = try XCTUnwrap(fields["frames"].flatMap(UInt64.init), value)
        let running = try XCTUnwrap(fields["running"].flatMap(Int.init), value)
        return DrawSnapshot(frames: frames, running: running)
    }

    private func sampleCounts(_ name: String, app: XCUIApplication) throws -> (start: DrawSnapshot, end: DrawSnapshot) {
        let start = try snapshot(app)
        Thread.sleep(forTimeInterval: 3)
        let end = try snapshot(app)
        let text = XCTAttachment(string: "window=\(name)\nseconds=3\nstart=\(start)\nend=\(end)")
        text.name = "liquid-draw-count-\(name)"; text.lifetime = .keepAlways; add(text)
        attach(app, "liquid-\(name)")
        return (start, end)
    }

    private func launchBudget(metricsProbe: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-design-preview", "-design-screen", "budgets", "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        if metricsProbe { app.launchArguments.append("-design-liquid-metrics") }
        app.launch()
        return app
    }

    private func attach(_ app: XCUIApplication, _ name: String) {
        let image = XCTAttachment(screenshot: app.screenshot())
        image.name = name; image.lifetime = .keepAlways; add(image)
    }
}
#endif
