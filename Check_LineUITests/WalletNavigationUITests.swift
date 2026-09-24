import XCTest
import UIKit

@MainActor
final class WalletNavigationUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    func testNativeTabsAndAgentKeepTheCurrentPage() throws {
        guard #available(iOS 27.0, *) else { throw XCTSkip("Native prominent tabs require iOS 27.") }
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .phone, "iPad retains the centered custom navigation.")
        let app = launch(screen: "home")
        let bar = app.tabBars.firstMatch
        XCTAssertTrue(bar.waitForExistence(timeout: 10))
        XCTAssertEqual(bar.buttons.count, 5, app.debugDescription)

        for index in [1, 2, 3, 0, 2, 1] {
            let tab = bar.buttons.element(boundBy: index)
            tab.tap()
            XCTAssertTrue(tab.isSelected)
        }
        let budget = bar.buttons.element(boundBy: 1)
        let agent = bar.buttons.element(boundBy: 4)
        XCTAssertEqual(budget.frame.midY, agent.frame.midY, accuracy: 4)
        XCTAssertGreaterThan(agent.frame.minX, bar.buttons.element(boundBy: 3).frame.maxX)
        attach(app, name: "native-tabs-before-agent")

        for _ in 0..<2 {
            agent.tap()
            let close = app.buttons["wallet.agent.close"]
            XCTAssertTrue(close.waitForExistence(timeout: 5), app.debugDescription)
            attach(app, name: "agent-sheet")
            close.tap()
            XCTAssertTrue(budget.waitForExistence(timeout: 5))
            XCTAssertTrue(budget.isSelected, "Closing Agent must preserve the selected page.")
        }
        attach(app, name: "native-tabs-after-agent")
    }

    func testEmptyHomeOffersReadableCreation() throws {
        let app = launch(screen: "empty")
        let create = app.buttons["wallet.empty.createBudget"]
        XCTAssertTrue(create.waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["还没有预算卡"].isHittable)
        XCTAssertTrue(app.staticTexts["为日常开销或一个计划，创建一张预算卡。"].isHittable)
        XCTAssertTrue(create.isHittable)
        attach(app, name: "empty-home")
        create.tap()
        XCTAssertTrue(app.textFields.firstMatch.waitForExistence(timeout: 5))
        attach(app, name: "create-from-empty-home")

        let name = app.textFields["输入预算名称"]
        name.tap()
        name.typeText("导航测试")
        let amount = app.textFields["额度"]
        amount.tap()
        amount.typeText("500")
        app.buttons.matching(NSPredicate(format: "label == %@ AND identifier != %@", "创建预算卡", "wallet.empty.createBudget")).firstMatch.tap()
        let undo = app.buttons["撤销"]
        XCTAssertTrue(undo.waitForExistence(timeout: 5))
        attach(app, name: "creation-feedback-above-tabs")
        if #available(iOS 27.0, *), UIDevice.current.userInterfaceIdiom == .phone {
            XCTAssertLessThanOrEqual(undo.frame.maxY, app.tabBars.firstMatch.frame.minY,
                                     "Action feedback must remain above the system tab bar.")
        }
        undo.tap()
        XCTAssertTrue(create.waitForExistence(timeout: 5))
    }

    func testNativeLensDragAndDetailReturn() throws {
        guard #available(iOS 27.0, *) else { throw XCTSkip("Native prominent tabs require iOS 27.") }
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .phone, "iPad retains the centered custom navigation.")
        let app = launch(screen: "home")
        let bar = app.tabBars.firstMatch
        XCTAssertTrue(bar.waitForExistence(timeout: 10))
        let home = bar.buttons.element(boundBy: 0)
        let analysis = bar.buttons.element(boundBy: 3)
        home.press(forDuration: 0.2, thenDragTo: analysis)
        XCTAssertTrue(analysis.isSelected)
        analysis.press(forDuration: 0.2, thenDragTo: home)
        XCTAssertTrue(home.isSelected)

        bar.buttons.element(boundBy: 2).tap()
        app.staticTexts["一副新耳机"].tap()
        XCTAssertTrue(bar.waitForNonExistence(timeout: 5), "A pushed detail must hide the root tab bar.")
        attach(app, name: "wish-detail-without-tab-bar")
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(bar.waitForExistence(timeout: 5))
        XCTAssertTrue(bar.buttons.element(boundBy: 2).isSelected)
    }

    private func launch(screen: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-design-preview", "-design-screen", screen, "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()
        return app
    }

    private func attach(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
