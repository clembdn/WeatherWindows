import XCTest

/// Captures the main screens in light, dark and the largest text size; CI exports them as an artifact.
final class ScreenshotTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testLightAppearance() {
        captureMainScreens(prefix: "light", appearance: .light)
    }

    @MainActor
    func testDarkAppearance() {
        captureMainScreens(prefix: "dark", appearance: .dark)
    }

    @MainActor
    func testLargestDynamicType() {
        captureMainScreens(
            prefix: "largest-text",
            appearance: .light,
            arguments: ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        )
    }

    @MainActor
    private func captureMainScreens(prefix: String, appearance: XCUIDevice.Appearance, arguments: [String] = []) {
        XCUIDevice.shared.appearance = appearance
        let app = XCUIApplication()
        app.launchArguments = ["--sample-data"] + arguments
        app.launch()

        capture(app, "\(prefix)-1-plan")

        tap(app.tabBars.buttons["Errands"])
        capture(app, "\(prefix)-2-errands")

        tap(app.buttons["Add Errand"].firstMatch)
        capture(app, "\(prefix)-3-new-errand")
        tap(app.buttons["Cancel"])

        tap(app.tabBars.buttons["About"])
        capture(app, "\(prefix)-4-about")

        app.terminate()
    }

    @MainActor
    private func tap(_ element: XCUIElement) {
        XCTAssertTrue(element.waitForExistence(timeout: 10), "\(element) not found")
        element.tap()
    }

    @MainActor
    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
