import XCTest

@MainActor
final class SecondaryRefinementUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        if #available(iOS 27.0, *) { try XCUIDevice.shared.voiceOverService.disable() }
    }

    func testRetrospectiveConfirmationKeepsPendingOnCancelAndConfirmsOnce() {
        let app = XCUIApplication()
        app.launchArguments = ["-design-preview", "-design-screen", "retrospective-record", "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()
        let confirm = app.buttons["确认当前归属"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["待确认"].exists)
        confirm.tap()
        let summary = app.staticTexts["确认这笔消费后，将修正原周期的结算结果与心愿钱包。"]
        XCTAssertTrue(summary.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["修正后的钱包"].exists)
        XCTAssertFalse(app.staticTexts["先说明对象、范围和金额影响，再明确确认；涉及历史与钱包时进入全屏影响核对。"].exists)
        attach(app, "retrospective-real-impact")
        app.buttons["取消"].tap()
        XCTAssertTrue(app.staticTexts["待确认"].waitForExistence(timeout: 5))
        XCTAssertTrue(summary.waitForNonExistence(timeout: 5))
        confirm.tap()
        XCTAssertTrue(summary.waitForExistence(timeout: 5))
        app.buttons["确认当前归属"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["已确认"].waitForExistence(timeout: 5))
        XCTAssertFalse(confirm.exists)
        attach(app, "retrospective-confirmed")
    }

    private func attach(_ app: XCUIApplication, _ name: String) {
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = name
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }
}
