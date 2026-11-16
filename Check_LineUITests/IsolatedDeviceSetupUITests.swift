import XCTest

/// Explicitly opt in only with the separately signed MotionQA app. This does
/// not grant network access or change the personal app's permissions.
@MainActor final class IsolatedDeviceSetupUITests: XCTestCase {
    func testDismissLocalQANetworkPrompt() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["CHECKLINE_ISOLATED_INPUT_QA"] == "1",
                          "Setup applies only to the separately installed synthetic QA app.")
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-design-preview", "-design-screen", "agent", "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()
        let system = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let alert = system.alerts.firstMatch
        if alert.waitForExistence(timeout: 4) {
            let network = alert.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "使用无线数据")).firstMatch
            XCTAssertTrue(network.exists, "An unrecognized system prompt must be handled explicitly.")
            guard network.exists else { return }
            alert.buttons["不允许"].tap()
            XCTAssertTrue(alert.waitForNonExistence(timeout: 4))
        }
        let input = app.descendants(matching: .any)["wallet.agent.input"].firstMatch
        XCTAssertTrue(input.waitForExistence(timeout: 6)); input.tap()
        input.typeText("Local QA")
        XCTAssertEqual(input.value as? String, "Local QA")
    }
}
