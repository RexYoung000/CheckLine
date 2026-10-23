import XCTest

@MainActor final class ComposerNavigationRegressionUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        #if targetEnvironment(simulator)
        if #available(iOS 27.0, *) { try XCUIDevice.shared.voiceOverService.disable() }
        #endif
    }

    func testCompactIconDockStaysCenteredAcrossTabsAndAgent() {
        checkCompactDock(englishLarge: false)
    }

    func testCompactIconDockWithEnglishLargeTextAndReducedMotion() {
        checkCompactDock(englishLarge: true)
    }

    private func checkCompactDock(englishLarge: Bool) {
        let app = XCUIApplication()
        app.launchArguments = ["-design-preview", "-design-screen", "r34-home", "-AppleLanguages", englishLarge ? "(en)" : "(zh-Hans)",
                               "-AppleLocale", englishLarge ? "en_US" : "zh_CN"]
        if englishLarge {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL", "-AppleInterfaceStyle", "Dark", "-design-reduce-motion"]
        }
        app.launch()
        let dock = app.descendants(matching: .any)["wallet.navigation"].firstMatch
        XCTAssertTrue(dock.waitForExistence(timeout: 10), app.debugDescription)
        let budget = dock.buttons["wallet.tab.budgets"], wish = dock.buttons["wallet.tab.wishes"], agent = dock.buttons["wallet.agent.avatar"]
        let originalFrame = dock.frame
        XCTAssertEqual(dock.buttons.count, 3)
        XCTAssertEqual(dock.staticTexts.count, 0, "The dock shows icons; names remain accessibility labels only.")
        // iOS 26 reports a container's child union, excluding the capsule's
        // five-point leading glass inset. Measure the rendered carriers instead.
        let carrierMidX = (budget.frame.minX - 5 + agent.frame.maxX) / 2
        XCTAssertEqual(carrierMidX, app.frame.midX, accuracy: 2)
        XCTAssertLessThan(dock.frame.width, min(260, app.frame.width * 0.65), "The three controls must form a compact centered group.")
        for button in [budget, wish, agent] {
            XCTAssertTrue(button.isHittable)
            XCTAssertGreaterThanOrEqual(button.frame.width, 44)
            XCTAssertGreaterThanOrEqual(button.frame.height, 44)
            XCTAssertFalse(button.label.isEmpty)
        }
        XCTAssertTrue(budget.isSelected)
        attach(app, englishLarge ? "compact-dock-english-large-budget" : "compact-dock-budget")
        wish.tap()
        XCTAssertTrue(app.buttons["native.wish.layout"].waitForExistence(timeout: 5))
        XCTAssertTrue(wish.isSelected); XCTAssertFalse(budget.isSelected)
        XCTAssertEqual(dock.frame.midX, originalFrame.midX, accuracy: 2)
        attach(app, englishLarge ? "compact-dock-english-large-wish" : "compact-dock-wish")
        agent.tap()
        let close = app.buttons["wallet.agent.close"]
        XCTAssertTrue(close.waitForExistence(timeout: 5)); close.tap()
        XCTAssertTrue(close.waitForNonExistence(timeout: 5))
        XCTAssertTrue(wish.isSelected, "Opening the agent must preserve the current page.")
        budget.tap()
        XCTAssertTrue(app.buttons["wallet.home.capture"].waitForExistence(timeout: 5))
        XCTAssertTrue(budget.isSelected)
        XCTAssertEqual(dock.frame.midX, originalFrame.midX, accuracy: 2)
        XCTAssertEqual(dock.staticTexts.count, 0)
        attach(app, englishLarge ? "compact-dock-english-large-restored" : "compact-dock-restored")
    }

    func testRecordingDismissalRestoresTabsAcrossRepeatedPresentations() {
        let app = XCUIApplication()
        app.launchArguments = ["-design-preview", "-design-screen", "r34-home", "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()
        let capture = app.buttons["wallet.home.capture"]
        XCTAssertTrue(capture.waitForExistence(timeout: 10), app.debugDescription)
        assertTabs(app)
        for index in 0..<2 {
            capture.tap()
            let close = app.buttons["wallet.composer.close"]
            XCTAssertTrue(close.waitForExistence(timeout: 5), app.debugDescription)
            attach(app, "recording-open-\(index)")
            close.tap()
            XCTAssertTrue(close.waitForNonExistence(timeout: 5))
            XCTAssertTrue(capture.waitForExistence(timeout: 5))
            assertTabs(app)
            attach(app, "recording-closed-\(index)")
        }
        let wish = tab("wishes", title: "心愿", in: app)
        wish.tap()
        XCTAssertTrue(app.buttons["native.wish.layout"].waitForExistence(timeout: 5), app.debugDescription)
        tab("budgets", title: "预算", in: app).tap()
        XCTAssertTrue(capture.waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 3)
        attach(app, "recording-roundtrip-liquid")
    }

    func testRecordFromBudgetDetailClosesOneSheetAndReturnsToUsableHome() {
        let app = XCUIApplication()
        app.launchArguments = ["-design-preview", "-design-screen", "r34-home", "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()
        let card = app.descendants(matching: .any)["wallet.home.card"].firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 10))
        card.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.3)).tap()
        let record = app.buttons["wallet.budget.record"]
        XCTAssertTrue(record.waitForExistence(timeout: 5), app.debugDescription)
        if !record.isHittable { app.swipeUp() }
        record.tap()
        let close = app.buttons["wallet.composer.close"]
        XCTAssertTrue(close.waitForExistence(timeout: 5), app.debugDescription)
        attach(app, "recording-from-detail-open")
        close.tap()
        XCTAssertTrue(close.waitForNonExistence(timeout: 5))
        let capture = app.buttons["wallet.home.capture"]
        XCTAssertTrue(capture.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(capture.isHittable)
        assertTabs(app)
    }

    func testSavingRecordAndClosingAgentPreservesNavigation() {
        let app = XCUIApplication()
        app.launchArguments = ["-design-preview", "-design-screen", "r34-home", "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()
        let capture = app.buttons["wallet.home.capture"]
        XCTAssertTrue(capture.waitForExistence(timeout: 10))
        capture.tap()
        let amount = app.textFields["输入金额"]
        XCTAssertTrue(amount.waitForExistence(timeout: 5)); amount.tap(); amount.typeText("12.34")
        app.buttons["wallet.keyboard.done"].tap()
        let save = app.buttons["wallet.composer.save"]
        XCTAssertTrue(save.isEnabled); save.tap()
        XCTAssertTrue(save.waitForNonExistence(timeout: 5))
        XCTAssertTrue(capture.isHittable)
        assertTabs(app)
        let agent = agentButton(in: app)
        XCTAssertTrue(agent.isHittable, app.debugDescription)
        agent.tap()
        let close = app.buttons["wallet.agent.close"]
        XCTAssertTrue(close.waitForExistence(timeout: 5)); close.tap()
        XCTAssertTrue(close.waitForNonExistence(timeout: 5))
        assertTabs(app)
        XCTAssertTrue(capture.isHittable)
        attach(app, "saved-record-agent-return-tabs-and-liquid")
    }

    func testNewFullBudgetKeepsLiquidAndTabsAfterRecordingCancel() {
        let app = XCUIApplication()
        app.launchArguments = ["-design-preview", "-design-screen", "budget-empty", "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()
        let create = app.buttons["wallet.header.create"]
        XCTAssertTrue(create.waitForExistence(timeout: 10)); create.tap()
        let name = app.textFields["wallet.composer.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5)); name.tap(); name.typeText("New budget")
        // On a short screen the fixed submit area and keyboard cover the next
        // field. Finish this field before tapping an amount that is now visible.
        app.buttons["wallet.keyboard.done"].tap()
        let amount = app.textFields["wallet.composer.amount"]
        amount.tap(); amount.typeText("100")
        app.buttons["wallet.keyboard.done"].tap()
        let save = app.buttons["wallet.composer.save"]
        XCTAssertTrue(save.isEnabled); save.tap()
        XCTAssertTrue(save.waitForNonExistence(timeout: 5))
        let card = app.descendants(matching: .any)["wallet.home.card"].firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 2)
        attach(app, "new-full-budget-liquid")
        app.buttons["wallet.home.capture"].tap()
        let close = app.buttons["wallet.composer.close"]
        XCTAssertTrue(close.waitForExistence(timeout: 5)); close.tap()
        XCTAssertTrue(close.waitForNonExistence(timeout: 5))
        assertTabs(app)
        Thread.sleep(forTimeInterval: 2)
        attach(app, "new-full-budget-recording-return")
    }

    func testWishPageAgentManualAndCreationDismissalKeepTabs() {
        let app = XCUIApplication()
        app.launchArguments = ["-design-preview", "-design-screen", "wishes", "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()
        XCTAssertTrue(app.buttons["native.wish.layout"].waitForExistence(timeout: 10))
        agentButton(in: app).tap()
        let switchMode = app.buttons["wallet.task.switchMode"]
        XCTAssertTrue(switchMode.waitForExistence(timeout: 5)); switchMode.tap()
        let close = app.buttons["wallet.composer.close"]
        XCTAssertTrue(close.waitForExistence(timeout: 5)); close.tap()
        XCTAssertTrue(close.waitForNonExistence(timeout: 5))
        assertTabs(app)
        XCTAssertTrue(app.buttons["native.wish.layout"].isHittable)
        app.buttons["wallet.header.create"].tap()
        XCTAssertTrue(app.textFields["wallet.wishes.name"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.matching(NSPredicate(format: "label == %@", "关闭")).firstMatch.tap()
        XCTAssertTrue(app.textFields["wallet.wishes.name"].waitForNonExistence(timeout: 5))
        assertTabs(app)
        tab("budgets", title: "预算", in: app).tap()
        XCTAssertTrue(app.buttons["wallet.home.capture"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["wallet.home.capture"].isHittable)
        attach(app, "wish-manual-create-return-tabs")
    }

    private func assertTabs(_ app: XCUIApplication) {
        for (id, title) in [("budgets", "预算"), ("wishes", "心愿")] {
            let button = tab(id, title: title, in: app)
            XCTAssertTrue(button.waitForExistence(timeout: 5), app.debugDescription)
            let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == true"), object: button)
            XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 5), .completed,
                           "\(title) must remain usable after recording closes.\n\(app.debugDescription)")
            XCTAssertGreaterThan(button.frame.midY, app.frame.height * 0.6, "This must be the bottom navigation button.")
        }
    }
    private func tab(_ id: String, title: String, in app: XCUIApplication) -> XCUIElement {
        // UIKit sometimes drops the SwiftUI label's identifier while rebuilding
        // the system bar. Its real TabBar role and user-facing label stay stable.
        let native = app.tabBars.buttons[title].firstMatch
        return native.exists ? native : app.buttons["wallet.tab.\(id)"].firstMatch
    }
    private func agentButton(in app: XCUIApplication) -> XCUIElement {
        let native = app.tabBars.buttons.matching(NSPredicate(format: "label CONTAINS %@", "小朵")).firstMatch
        return native.exists ? native : app.buttons["wallet.agent.avatar"].firstMatch
    }
    private func attach(_ app: XCUIApplication, _ name: String) {
        let image = XCTAttachment(screenshot: app.screenshot())
        image.name = name; image.lifetime = .keepAlways; add(image)
    }
}
