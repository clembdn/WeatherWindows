import XCTest

/// Captures the main screens in light, dark and the largest text size; CI exports them as an artifact.
nonisolated final class ScreenshotTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testLightAppearance() {
        captureMainScreens(prefix: "light", appearance: .light, includesPlanFlow: true)
    }

    @MainActor
    func testDarkAppearance() {
        captureMainScreens(prefix: "dark", appearance: .dark, includesPlanFlow: true)
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
    private func captureMainScreens(prefix: String, appearance: XCUIDevice.Appearance,
                                    arguments: [String] = [], includesPlanFlow: Bool = false) {
        XCUIDevice.shared.appearance = appearance
        let app = XCUIApplication()
        app.launchArguments = ["--sample-data"] + arguments
        app.launch()

        capture(app, "\(prefix)-1-plan")

        tap(app.tabBars.buttons["Errands"])
        capture(app, "\(prefix)-2-errands")

        tap(app.buttons["Add Errand"].firstMatch)
        capture(app, "\(prefix)-3-new-errand")
        if app.buttons["Cancel"].waitForExistence(timeout: 5) {
            app.buttons["Cancel"].tap()
        } else {
            app.swipeDown(velocity: .fast)
        }

        tap(app.tabBars.buttons["About"])
        capture(app, "\(prefix)-4-about")

        if includesPlanFlow {
            tap(app.tabBars.buttons["Plan"])
            for name in ["Post Office", "Coles", "Library"] {
                tap(app.buttons["errand-\(name)"])
            }
            tap(app.buttons["calculate"])
            XCTAssertTrue(app.navigationBars["Results"].waitForExistence(timeout: 30), "Results never appeared")
            capture(app, "\(prefix)-5-results")

            tap(app.buttons["plan-card"].firstMatch)
            XCTAssertTrue(app.navigationBars["Itinerary"].waitForExistence(timeout: 10), "Itinerary never appeared")
            capture(app, "\(prefix)-6-itinerary")

            tap(app.buttons["check-radar"])
            XCTAssertTrue(app.otherElements["Rain map"].waitForExistence(timeout: 30)
                          || app.staticTexts["Nothing Fits Any More"].waitForExistence(timeout: 5),
                          "Radar advice never appeared")
            capture(app, "\(prefix)-7-next-walk")
        }

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
