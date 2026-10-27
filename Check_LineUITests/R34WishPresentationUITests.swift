import XCTest

@MainActor final class R34WishPresentationUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        if #available(iOS 27.0, *) { try XCUIDevice.shared.voiceOverService.disable() }
    }

    func testWishCardsUseTwoColumnsAndOddLastCardSpansThenSwitchToRows() {
        let app = launchWishes()
        let cards = wishCards(in: app).allElementsBoundByIndex.sorted {
            abs($0.frame.minY - $1.frame.minY) > 4 ? $0.frame.minY < $1.frame.minY : $0.frame.minX < $1.frame.minX
        }
        XCTAssertEqual(cards.count, 3, "The synthetic wish fixture contains three wishes.")
        guard cards.count == 3 else { return }
        let first = cards[0].frame, second = cards[1].frame, last = cards[2].frame
        XCTAssertEqual(first.minY, second.minY, accuracy: 4)
        XCTAssertGreaterThan(second.minX, first.maxX + 4)
        XCTAssertEqual(first.width, second.width, accuracy: 3)
        XCTAssertGreaterThan(last.width, first.width * 1.7,
                             "An odd last wish uses a wide card instead of leaving an empty column.")
        XCTAssertGreaterThan(last.minY, first.maxY)
        attach(app, "r34-wish-two-columns-and-wide-last")

        app.buttons["native.wish.layout"].tap()
        let rows = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "native.wish.card.")).allElementsBoundByIndex
        XCTAssertEqual(rows.count, 3)
        for row in rows {
            XCTAssertGreaterThan(row.frame.width, first.width * 1.7)
            XCTAssertLessThan(row.frame.height, 160)
        }
        attach(app, "r34-wish-horizontal-liquid-rows")
    }

    func testExpandedWishIsActuallyLargerAndGestureTurnsToRedeemableBack() {
        let app = launchWishes()
        let small = wishCards(in: app).allElementsBoundByIndex.first {
            $0.frame.width < app.frame.width * 0.7 && !$0.staticTexts["去山里露营"].exists
        } ?? wishCards(in: app).firstMatch
        let identifier = small.identifier
        let smallFrame = small.frame
        let expand = small.buttons["native.wish.expand"].firstMatch
        XCTAssertTrue(expand.isHittable)
        expand.tap()
        let expanded = app.descendants(matching: .any)["native.wish.expanded"].firstMatch
        XCTAssertTrue(expanded.waitForExistence(timeout: 5), app.debugDescription)
        let card = expanded.descendants(matching: .any)[identifier].firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertGreaterThan(card.frame.width, smallFrame.width * 1.6,
                             "Expanding must present a larger card, not the same small card on a dark background.")
        XCTAssertGreaterThan(card.frame.height, smallFrame.height * 1.25)
        waitForValue(card, containing: "正面")
        XCTAssertFalse(card.buttons["native.wish.expand"].exists,
                       "The expanded card does not need another nested expand button.")
        attach(app, "r34-wish-expanded-front-scale")

        let start = card.coordinate(withNormalizedOffset: CGVector(dx: 0.82, dy: 0.45))
        start.press(forDuration: 0.06, thenDragTo: start.withOffset(CGVector(dx: -card.frame.width * 0.56, dy: 0)))
        waitForValue(card, containing: "背面")
        let redeem = card.buttons["native.wish.redeem"].firstMatch
        waitUntilActionable(redeem)
        XCTAssertTrue(redeem.isHittable, "Only the active back face may receive redemption input.")
        XCTAssertTrue(redeem.isEnabled)
        XCTAssertEqual(redeem.label, "兑换")
        XCTAssertFalse(card.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "还差")).firstMatch.exists)
        XCTAssertFalse(card.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "可用")).firstMatch.exists)
        attach(app, "r34-wish-expanded-liquid-back")

        // Entering review must not complete a purchase or change the list's phase.
        redeem.tap()
        XCTAssertTrue(app.textFields["wallet.wishes.actual"].waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(app.switches["wallet.wishes.purchaseConfirmed"].exists)
        XCTAssertFalse(app.buttons["wallet.wishes.confirm"].isEnabled,
                       "Opening redemption cannot replace explicit real-purchase confirmation.")
        attach(app, "r34-wish-redemption-still-requires-confirmation")
    }

    func testWishRowOpensExpandedCardAndIncompleteButtonDoesNotFlip() {
        let app = launchWishes()
        app.buttons["native.wish.layout"].tap()
        let row = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label == %@", "native.wish.card.", "去山里露营")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        let identifier = row.identifier
        row.tap()
        let expanded = app.descendants(matching: .any)["native.wish.expanded"].firstMatch
        XCTAssertTrue(expanded.waitForExistence(timeout: 5))
        let card = expanded.descendants(matching: .any)[identifier].firstMatch
        card.coordinate(withNormalizedOffset: CGVector(dx: 0.4, dy: 0.36)).tap()
        waitForValue(card, containing: "背面")
        let redeem = card.buttons["native.wish.redeem"].firstMatch
        XCTAssertTrue(redeem.waitForExistence(timeout: 5))
        XCTAssertFalse(redeem.isEnabled, "Reference coverage below 100% must disable redemption.")
        redeem.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue((card.value as? String)?.contains("背面") == true,
                      "The disabled action strip must not fall through to the flip surface.")
        XCTAssertFalse(app.textFields["wallet.wishes.actual"].exists)
        attach(app, "wish-row-expanded-incomplete-action-isolated")
    }

    private func launchWishes() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-design-preview", "-design-screen", "wishes", "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()
        XCTAssertTrue(app.buttons["native.wish.balance"].waitForExistence(timeout: 10), app.debugDescription)
        XCTAssertTrue(wishCards(in: app).firstMatch.waitForExistence(timeout: 5), app.debugDescription)
        return app
    }

    private func wishCards(in app: XCUIApplication) -> XCUIElementQuery {
        app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@", "native.wish.card."))
    }

    private func waitForValue(_ element: XCUIElement, containing expected: String, file: StaticString = #filePath, line: UInt = #line) {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value CONTAINS %@", expected), object: element)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 5), .completed,
                       "Expected the current wish face to be \(expected).", file: file, line: line)
    }

    private func waitUntilActionable(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == true AND enabled == true AND hittable == true"), object: element)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 8), .completed,
                       "A fully covered wish must become actionable only after its back face settles.", file: file, line: line)
    }

    private func attach(_ app: XCUIApplication, _ name: String) {
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = name
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }
}
