import XCTest
import UIKit

@MainActor final class PhoneFeedbackRepairUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        #if targetEnvironment(simulator)
        if #available(iOS 27.0, *) { try XCUIDevice.shared.voiceOverService.disable() }
        #endif
    }

    func testLongPressThenSlowDownAndUpDragSettlesWithoutRepeatedMotion() {
        let app = launch(), card = element("wallet.home.card", in: app)
        let original = card.frame
        for _ in 0..<2 {
            let down = card.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.3))
            down.press(forDuration: 0.65, thenDragTo: down.withOffset(CGVector(dx: 0, dy: 85)), withVelocity: .slow, thenHoldForDuration: 1.4)
            wait(card, value: "已插入")
            XCTAssertEqual(card.frame.minY, original.minY, accuracy: 3)
            let up = card.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.3))
            up.press(forDuration: 0.65, thenDragTo: up.withOffset(CGVector(dx: 0, dy: -72)), withVelocity: .slow, thenHoldForDuration: 1.4)
            wait(card, value: "已拔出")
            let settled = card.frame
            Thread.sleep(forTimeInterval: 1.2)
            XCTAssertEqual(card.frame.minY, settled.minY, accuracy: 2)
            card.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.3)).tap()
            wait(card, value: "已插入")
        }
        attach(app, "phone-card-held-drag-repeated-settled")
    }

    func testArcPullShortCancelArrowAndEdgeDragReturn() {
        let app = launch(), library = element("native.budget.library", in: app)
        app.buttons["native.holder.down"].tap()
        XCTAssertTrue(library.waitForExistence(timeout: 5))
        let scene = element("native.library.surface", in: app)
        let short = scene.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        short.press(forDuration: 0.08, thenDragTo: short.withOffset(CGVector(dx: 0, dy: 24)))
        XCTAssertTrue(library.exists)
        let pull = scene.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        pull.press(forDuration: 0.08, thenDragTo: pull.withOffset(CGVector(dx: 0, dy: 140)), withVelocity: .slow, thenHoldForDuration: 0.5)
        XCTAssertTrue(library.waitForNonExistence(timeout: 5), app.debugDescription)
        app.buttons["native.holder.down"].tap()
        XCTAssertTrue(library.waitForExistence(timeout: 5))
        let grip = element("native.library.return", in: app)
        grip.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.5)).tap()
        XCTAssertTrue(library.exists)
        app.buttons["native.library.returnButton"].tap()
        XCTAssertTrue(library.waitForNonExistence(timeout: 5), app.debugDescription)
        app.buttons["native.holder.down"].tap()
        XCTAssertTrue(library.waitForExistence(timeout: 5))
        let edge = library.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: 0.4))
        edge.press(forDuration: 0.08, thenDragTo: edge.withOffset(CGVector(dx: 0, dy: 130)))
        XCTAssertTrue(library.waitForNonExistence(timeout: 5), app.debugDescription)
        attach(app, "phone-library-three-return-paths")
    }

    func testExpenseDetailDeleteCancelThenConfirmReturnsToRecords() {
        let app = launch()
        app.buttons["native.holder.up"].tap()
        let records = element("native.budget.records", in: app)
        XCTAssertTrue(records.waitForExistence(timeout: 5))
        let row = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "native.record.")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        let identifier = row.identifier
        row.tap()
        let remove = app.buttons["expense.delete.open"]
        XCTAssertTrue(remove.waitForExistence(timeout: 5), app.debugDescription)
        remove.tap()
        let confirm = app.buttons["expense.delete.confirm"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5), app.debugDescription)
        attach(app, "phone-delete-impact-before-confirm")
        app.buttons["expense.delete.close"].tap()
        XCTAssertTrue(remove.waitForExistence(timeout: 5))
        remove.tap()
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.tap()
        XCTAssertTrue(records.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(app.buttons[identifier].waitForNonExistence(timeout: 5))
        attach(app, "phone-detail-deletion-returned-to-records")
    }

    func testLeftSwipeOnlyOpensDeletionReview() {
        let app = launch()
        app.buttons["native.holder.up"].tap()
        let row = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "native.record.")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        let identifier = row.identifier
        row.swipeLeft(velocity: .slow)
        let remove = app.buttons["expense.delete.swipe"]
        XCTAssertTrue(remove.waitForExistence(timeout: 5), app.debugDescription)
        attach(app, "phone-native-left-swipe-delete-action")
        remove.tap()
        XCTAssertTrue(app.buttons["expense.delete.confirm"].waitForExistence(timeout: 5), app.debugDescription)
        app.buttons["expense.delete.close"].tap()
        XCTAssertTrue(app.buttons[identifier].waitForExistence(timeout: 5))
        app.buttons[identifier].swipeLeft(velocity: .slow)
        XCTAssertTrue(remove.waitForExistence(timeout: 5))
        remove.tap()
        let confirm = app.buttons["expense.delete.confirm"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.tap()
        XCTAssertTrue(app.buttons[identifier].waitForNonExistence(timeout: 5), "Only the final confirmation may remove the row.")
    }

    func testAmbientBubblesContinueBeyondBurstAndWhileDetached() {
        let app = launch(), card = element("wallet.home.card", in: app)
        Thread.sleep(forTimeInterval: 6)
        attach(app, "phone-ambient-after-burst-duration")
        let firstLiquidFrame = card.screenshot().pngRepresentation
        Thread.sleep(forTimeInterval: 3)
        attach(app, "phone-ambient-still-running")
        if !UIAccessibility.isReduceMotionEnabled {
            XCTAssertNotEqual(firstLiquidFrame, card.screenshot().pngRepresentation,
                              "The actual card pixels must continue changing after the insertion burst ends.")
        }
        card.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.3)).press(forDuration: 0.65)
        wait(card, value: "已拔出")
        Thread.sleep(forTimeInterval: 3)
        attach(app, "phone-detached-liquid-still-alive")
    }

    func testRecordsKeepScrollPositionAcrossLayerReturn() {
        let app = launch()
        app.buttons["native.holder.up"].tap()
        let records = element("native.budget.records", in: app)
        XCTAssertTrue(records.waitForExistence(timeout: 5))
        records.swipeUp(velocity: .slow)
        if let probe = records.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "native.record.")).allElementsBoundByIndex.first(where: { $0.isHittable }) {
            var last = probe.frame.minY, stable = 0
            for _ in 0..<15 {
                Thread.sleep(forTimeInterval: 0.15)
                let y = probe.frame.minY
                stable = abs(y - last) < 0.5 ? stable + 1 : 0
                last = y
                if stable >= 3 { break }
            }
            XCTAssertGreaterThanOrEqual(stable, 3, "Measure the reading position only after native deceleration has stopped.")
        }
        let visible = records.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "native.record.")).allElementsBoundByIndex
            .filter { $0.isHittable && $0.frame.midY > records.frame.minY + 20 }.sorted { $0.frame.minY < $1.frame.minY }
        guard let row = visible.first else { XCTFail("Expected visible scrolled records"); return }
        let identifier = row.identifier, y = row.frame.minY
        let beforeViewport = records.frame
        attach(app, "phone-records-before-layer-return")
        app.buttons["native.holder.down"].tap()
        XCTAssertTrue(records.waitForNonExistence(timeout: 5))
        app.buttons["native.holder.up"].tap()
        XCTAssertTrue(records.waitForExistence(timeout: 5))
        let restored = app.buttons[identifier]
        let diagnostic = XCTAttachment(string: "Before viewport \(beforeViewport), row y \(y); after viewport \(records.frame), row \(restored.frame).")
        diagnostic.name = "phone-record-reading-geometry"; diagnostic.lifetime = .keepAlways; add(diagnostic)
        XCTAssertTrue(restored.isHittable)
        XCTAssertEqual(restored.frame.minY, y, accuracy: 26, "Returning to the records layer must preserve the reading position.")
        attach(app, "phone-records-reading-position-restored")
    }

    func testReducedMotionPreservesHoldInsertAndLibraryReturn() {
        let app = launch(reducedMotion: true), card = element("wallet.home.card", in: app)
        card.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.3)).press(forDuration: 0.65)
        wait(card, value: "已拔出")
        card.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.3)).tap()
        wait(card, value: "已插入")
        attach(app, "phone-reduced-motion-card-static")
        app.buttons["native.holder.down"].tap()
        let library = element("native.budget.library", in: app)
        XCTAssertTrue(library.waitForExistence(timeout: 5))
        app.buttons["native.library.returnButton"].tap()
        XCTAssertTrue(library.waitForNonExistence(timeout: 5))
    }

    private func launch(reducedMotion: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-design-preview", "-design-screen", "r34-home", "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        if reducedMotion { app.launchArguments.append("-design-reduce-motion") }
        app.launch()
        XCTAssertTrue(app.buttons["wallet.home.capture"].waitForExistence(timeout: 10), app.debugDescription)
        return app
    }
    private func element(_ id: String, in app: XCUIApplication) -> XCUIElement { app.descendants(matching: .any)[id].firstMatch }
    private func wait(_ element: XCUIElement, value: String) {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value CONTAINS %@", value), object: element)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 6), .completed, "Expected \(value), got \(String(describing: element.value))")
    }
    private func attach(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = name; shot.lifetime = .keepAlways; add(shot)
    }
}
