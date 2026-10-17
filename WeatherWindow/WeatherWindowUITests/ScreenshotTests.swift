//
//  ScreenshotTests.swift
//  WeatherWindowUITests
//
//  Created by Clement Boudon on 7/10/2026.
//

import XCTest

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
        captureMainScreens(prefix: "dark", appearance: .dark, arguments: ["--dark"], includesPlanFlow: true)
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
    func testLandscape() {
        XCUIDevice.shared.appearance = .light
        let app = XCUIApplication()
        app.launchArguments = ["--sample-data", "-replayMode", "YES"]
        app.launch()
        rotateToLandscape()

        capture(app, "landscape-1-plan")
        tap(app.tabBars.buttons["Errands"])
        capture(app, "landscape-2-errands")
        tap(app.tabBars.buttons["About"])
        capture(app, "landscape-3-about")

        XCUIDevice.shared.orientation = .portrait
        app.terminate()
    }

    @MainActor
    func testLandscapePlanFlow() {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["--sample-data", "-replayMode", "YES", "--dark"]
        app.launch()

        openResults(app)
        openItinerary(app)
        rotateToLandscape()
        capture(app, "landscape-4-itinerary")

        XCUIDevice.shared.orientation = .portrait
        tap(app.buttons["check-radar"])
        let appeared = app.descendants(matching: .any)["Rain map"].waitForExistence(timeout: 60)
        XCTAssertTrue(appeared, "Radar advice never appeared")
        rotateToLandscape()
        app.swipeUp()
        capture(app, "landscape-5-next-walk")

        XCUIDevice.shared.orientation = .portrait
        app.terminate()
    }

    @MainActor
    func testAppearanceSetting() {
        XCUIDevice.shared.appearance = .light
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["--sample-data", "-replayMode", "YES", "-appearance", "dark"]
        app.launch()

        tap(app.tabBars.buttons["About"])
        capture(app, "appearance-setting-dark")
        app.terminate()
    }

    @MainActor
    private func rotateToLandscape() {
        XCUIDevice.shared.orientation = .landscapeLeft
        // Give the rotation animation time to finish before the next screenshot.
        Thread.sleep(forTimeInterval: 2)
    }

    @MainActor
    private func openResults(_ app: XCUIApplication) {
        tap(app.tabBars.buttons["Plan"])
        for name in ["Post Office", "Coles", "Library"] {
            tap(app.buttons["errand-\(name)"])
        }
        tap(app.buttons["calculate"])
        XCTAssertTrue(app.navigationBars["Results"].waitForExistence(timeout: 30), "Results never appeared")
    }

    @MainActor
    private func openItinerary(_ app: XCUIApplication) {
        tap(app.buttons["plan-card"].firstMatch)
        XCTAssertTrue(app.navigationBars["Itinerary"].waitForExistence(timeout: 10), "Itinerary never appeared")
    }

    @MainActor
    private func openNextWalk(_ app: XCUIApplication, captureAs name: String) {
        tap(app.buttons["check-radar"])
        let appeared = app.descendants(matching: .any)["Rain map"].waitForExistence(timeout: 60)
        capture(app, name)
        XCTAssertTrue(appeared, "Radar advice never appeared")
    }

    @MainActor
    private func captureMainScreens(prefix: String, appearance: XCUIDevice.Appearance,
                                    arguments: [String] = [], includesPlanFlow: Bool = false) {
        XCUIDevice.shared.appearance = appearance
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["--sample-data", "-replayMode", "YES"] + arguments
        app.launch()

        capture(app, "\(prefix)-1-plan")

        tap(app.tabBars.buttons["Errands"])
        capture(app, "\(prefix)-2-errands")

        tap(app.buttons["Add Errand"].firstMatch)
        let sheet = app.navigationBars["New Errand"]
        XCTAssertTrue(sheet.waitForExistence(timeout: 30), "New Errand sheet never opened")
        capture(app, "\(prefix)-3-new-errand")
        tap(app.buttons["Cancel"])
        XCTAssertTrue(sheet.waitForNonExistence(timeout: 30), "New Errand sheet never closed")

        tap(app.tabBars.buttons["About"])
        capture(app, "\(prefix)-4-about")

        if includesPlanFlow {
            openResults(app)
            capture(app, "\(prefix)-5-results")

            openItinerary(app)
            capture(app, "\(prefix)-6-itinerary")

            openNextWalk(app, captureAs: "\(prefix)-7-next-walk")
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
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
