//
//  VoiceOverTests.swift
//  WeatherWindowUITests
//
//  Created by Clement Boudon on 29/10/2026.
//

import XCTest

/// The simulator has no VoiceOver, so this test reads what VoiceOver would read: the traits, labels
/// and values set by hand on the errand rows, the plan cards and the rain map.
nonisolated final class VoiceOverTests: XCTestCase {
    @MainActor
    func testVoiceOverReadsSelectionRainAndConfidence() {
        XCUIDevice.shared.appearance = .light
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["--sample-data", "-replayMode", "YES", "-startsAtPlace", "NO"]
        app.launch()

        // Trait: a chosen errand is announced as "selected", not only shown by its check mark.
        let postOffice = app.buttons["errand-Post Office"]
        XCTAssertTrue(postOffice.waitForExistence(timeout: 30), "Plan screen never appeared")
        XCTAssertFalse(postOffice.isSelected, "Post Office should start unselected")
        postOffice.tap()
        for _ in 1...10 where !postOffice.isSelected {
            Thread.sleep(forTimeInterval: 0.5)
        }
        XCTAssertTrue(postOffice.isSelected, "A chosen errand should have the selected trait")

        for name in ["Coles", "Library"] {
            app.buttons["errand-\(name)"].tap()
        }
        app.buttons["calculate"].tap()
        XCTAssertTrue(app.navigationBars["Results"].waitForExistence(timeout: 30), "Results never appeared")

        // Labels: the card reads rain and confidence in words, without "~" or "3/3".
        let card = app.buttons["plan-card"].firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 10), "No plan card")
        XCTContext.runActivity(named: "Plan card label: \(card.label)") { _ in }
        XCTAssertFalse(card.label.contains("~"), "The card label still has a tilde: \(card.label)")
        XCTAssertTrue(card.label.contains("out of 3"), "The card label should read the confidence out of 3: \(card.label)")

        // Value: the rain map gives the time shown and the rain at your position.
        card.tap()
        XCTAssertTrue(app.navigationBars["Itinerary"].waitForExistence(timeout: 10), "Itinerary never appeared")
        let rainMap = app.descendants(matching: .any)["Rain map"]
        app.buttons["check-radar"].tap()
        XCTAssertTrue(rainMap.waitForExistence(timeout: 60), "Radar advice never appeared")
        let value = rainMap.value as? String ?? ""
        XCTContext.runActivity(named: "Rain map value: \(value)") { _ in }
        XCTAssertTrue(value.contains("at your position"), "The rain map value should describe the rain at your position: \(value)")
    }
}
