import XCTest

/// Run on the dedicated simulator after simctl addmedia installs one synthetic
/// image. Never opens the personal phone's photo library.
@MainActor final class WishPhotoFlowUITests: XCTestCase {
    func testSystemPhotoPickerAppliesAndRetainsWishCover() throws {
        #if !targetEnvironment(simulator)
        throw XCTSkip("Photo input uses only a dedicated simulator's synthetic library.")
        #else
        try XCTSkipUnless(ProcessInfo.processInfo.environment["CHECKLINE_SYNTHETIC_PHOTO_QA"] == "1",
                          "Requires a simulator with one seeded synthetic image.")
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-design-preview", "-design-screen", "wishes-empty", "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()
        let add = app.buttons["wallet.header.create"]
        XCTAssertTrue(add.waitForExistence(timeout: 8)); add.tap()
        let name = app.textFields["wallet.wishes.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5)); name.tap(); name.typeText("Photo QA")
        app.buttons["完成输入"].firstMatch.tap()
        app.buttons["native.cover.open"].tap()
        app.segmentedControls["native.cover.source"].buttons["我的图片"].tap()
        let choose = app.buttons["选择图片"]
        XCTAssertTrue(choose.waitForExistence(timeout: 5)); choose.tap()
        let photo = app.scrollViews["photosView_content_scroll_view"].images.matching(identifier: "PXGGridLayout-Info").firstMatch
        guard photo.waitForExistence(timeout: 8) else {
            attach(app, "system-photo-picker-tree")
            return XCTFail("The seeded photo must be visible in the actual system picker.\n\(app.debugDescription)")
        }
        photo.tap()
        let confirm = app.buttons["添加"].firstMatch
        if confirm.exists, confirm.isHittable { confirm.tap() }
        let remove = app.buttons["移除图片"]
        XCTAssertTrue(remove.waitForExistence(timeout: 8), app.debugDescription)
        let fill = app.segmentedControls.buttons["铺满卡面"]
        fill.tap()
        XCTAssertTrue(fill.isSelected)
        let horizontal = app.sliders["图片水平位置"]
        let vertical = app.sliders["图片垂直位置"]
        revealPhotoControl(horizontal, in: app)
        horizontal.adjust(toNormalizedSliderPosition: 0.75)
        revealPhotoControl(vertical, in: app)
        vertical.adjust(toNormalizedSliderPosition: 0.25)
        let savedHorizontal = horizontal.value as? String
        let savedVertical = vertical.value as? String
        XCTAssertNotNil(savedHorizontal)
        XCTAssertNotNil(savedVertical)
        XCTAssertNotEqual(savedHorizontal, "50%")
        XCTAssertNotEqual(savedVertical, "50%")
        attach(app, "photo-position-controls-above-fixed-save")
        app.buttons["native.cover.save"].tap()
        XCTAssertTrue(name.waitForExistence(timeout: 5)); XCTAssertEqual(name.value as? String, "Photo QA")
        app.buttons["wallet.wishes.create.save"].tap()
        XCTAssertTrue(app.staticTexts["Photo QA"].waitForExistence(timeout: 5))
        app.buttons["native.wish.expand"].firstMatch.tap()
        XCTAssertTrue(app.buttons["native.wish.cover.edit"].waitForExistence(timeout: 5))
        app.buttons["native.wish.cover.edit"].tap()
        XCTAssertTrue(remove.waitForExistence(timeout: 5))
        XCTAssertTrue(fill.isSelected, "The saved wish must retain the imported photo and selected layout.")
        revealPhotoControl(horizontal, in: app)
        XCTAssertEqual(horizontal.value as? String, savedHorizontal)
        revealPhotoControl(vertical, in: app)
        XCTAssertEqual(vertical.value as? String, savedVertical)
        attach(app, "photo-cover-retained-after-saving-wish")
        #endif
    }

    private func revealPhotoControl(_ control: XCUIElement, in app: XCUIApplication) {
        let form = app.scrollViews.containing(.segmentedControl, identifier: "native.cover.source").firstMatch
        XCTAssertTrue(form.waitForExistence(timeout: 5))
        let save = app.buttons["native.cover.save"]
        for _ in 0..<6 {
            let top = form.frame.intersection(app.frame).minY + 16
            let bottom = min(form.frame.maxY, save.frame.minY) - 16
            if control.isHittable, control.frame.minY >= top, control.frame.maxY <= bottom { return }
            guard bottom > top + 44 else { break }
            let origin = form.coordinate(withNormalizedOffset: .zero)
            let upper = origin.withOffset(CGVector(dx: form.frame.width * 0.5, dy: top - form.frame.minY))
            let lower = origin.withOffset(CGVector(dx: form.frame.width * 0.5, dy: bottom - form.frame.minY))
            if control.frame.maxY > bottom { lower.press(forDuration: 0.05, thenDragTo: upper) }
            else { upper.press(forDuration: 0.05, thenDragTo: lower) }
        }
        attach(app, "photo-position-control-not-reachable")
        XCTFail("The photo position control must be fully reachable above the fixed save action.")
    }

    private func attach(_ app: XCUIApplication, _ name: String) {
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = name; screenshot.lifetime = .keepAlways; add(screenshot)
        let tree = XCTAttachment(string: app.debugDescription)
        tree.name = name + "-hierarchy"; tree.lifetime = .keepAlways; add(tree)
    }
}
