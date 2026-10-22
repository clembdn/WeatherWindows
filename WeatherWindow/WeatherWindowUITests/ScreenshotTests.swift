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
        app.launchArguments = ["--sample-data", "-replayMode", "YES", "-startsAtPlace", "NO"]
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
        app.launchArguments = ["--sample-data", "-replayMode", "YES", "-startsAtPlace", "NO", "--dark"]
        app.launch()

        openResults(app)
        openItinerary(app)
        rotateToLandscape()
        capture(app, "landscape-4-itinerary")
        app.swipeUp()
        Thread.sleep(forTimeInterval: 1)
        capture(app, "landscape-6-route-map")
        app.swipeDown()
        Thread.sleep(forTimeInterval: 1)

        tap(app.buttons["check-radar"])
        let loaded = app.switches["Alert Me If Rain Is Coming"].waitForExistence(timeout: 60)
        XCTAssertTrue(loaded, "Radar advice never appeared")
        app.swipeUp()
        Thread.sleep(forTimeInterval: 1)
        capture(app, "landscape-5-next-walk")

        XCUIDevice.shared.orientation = .portrait
        app.terminate()
    }

    @MainActor
    func testLandscapeMaps() {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["--sample-data", "-replayMode", "YES", "-startsAtPlace", "NO", "--dark"]
        app.launch()

        openResults(app)
        openItinerary(app)
        let routeMap = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH 'Map of the route'")).firstMatch
        record(routeMap, "route-map-portrait")
        app.swipeUp()
        for (attempt, points) in ([150, 40, 40] as [CGFloat]).enumerated() {
            drag(app, by: points)
            rotateToLandscape()
            capture(app, "landscape-6-route-map-\(attempt + 1)")
            record(routeMap, "route-map-landscape-\(attempt + 1)")
            XCUIDevice.shared.orientation = .portrait
            Thread.sleep(forTimeInterval: 2)
        }

        app.terminate()
        app.launch()
        openResults(app)
        openItinerary(app)
        openNextWalk(app, captureAs: "portrait-7-next-walk")
        let radarMap = app.descendants(matching: .any)["Rain map"]
        record(radarMap, "radar-map-portrait")
        app.swipeUp()
        for (attempt, points) in ([-120, -40, -40] as [CGFloat]).enumerated() {
            drag(app, by: points)
            rotateToLandscape()
            capture(app, "landscape-7-radar-\(attempt + 1)")
            record(radarMap, "radar-map-landscape-\(attempt + 1)")
            XCUIDevice.shared.orientation = .portrait
            Thread.sleep(forTimeInterval: 2)
        }

        app.terminate()
    }

    @MainActor
    private func drag(_ app: XCUIApplication, by points: CGFloat) {
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let end = start.withOffset(CGVector(dx: 0, dy: points))
        start.press(forDuration: 0.2, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.5)
        Thread.sleep(forTimeInterval: 1)
    }

    @MainActor
    private func record(_ element: XCUIElement, _ name: String) {
        let text = element.exists ? "\(name): \(element.frame)" : "\(name): not found"
        let attachment = XCTAttachment(string: text)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testAppearanceSetting() {
        XCUIDevice.shared.appearance = .light
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["--sample-data", "-replayMode", "YES", "-startsAtPlace", "NO", "-appearance", "dark"]
        app.launch()

        tap(app.tabBars.buttons["About"])
        capture(app, "appearance-setting-dark")
        app.terminate()
    }

    @MainActor
    private func rotateToLandscape() {
        XCUIDevice.shared.orientation = .landscapeLeft
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
        app.launchArguments = ["--sample-data", "-replayMode", "YES", "-startsAtPlace", "NO"] + arguments
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

            tap(app.buttons["Compare the Next 7 Days"])
            XCTAssertTrue(app.navigationBars["Next 7 Days"].waitForExistence(timeout: 10), "Next 7 Days never appeared")
            XCTAssertTrue(app.staticTexts["Checking the next 7 days…"].waitForNonExistence(timeout: 30), "Next 7 Days never loaded")
            capture(app, "\(prefix)-8-best-day")
            tap(app.navigationBars["Next 7 Days"].buttons.firstMatch)
            XCTAssertTrue(app.navigationBars["Results"].waitForExistence(timeout: 10), "Results never came back")

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
