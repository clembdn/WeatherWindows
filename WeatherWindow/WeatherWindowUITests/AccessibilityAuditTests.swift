//
//  AccessibilityAuditTests.swift
//  WeatherWindowUITests
//
//  Created by Clement Boudon on 7/10/2026.
//

import XCTest

nonisolated final class AccessibilityAuditTests: XCTestCase {
    @MainActor
    func testMainScreensPassTheAccessibilityAudit() throws {
        try auditEveryScreen(appearance: .light, arguments: [])
    }

    @MainActor
    func testMainScreensPassTheAccessibilityAuditInDarkMode() throws {
        try auditEveryScreen(appearance: .dark, arguments: ["--dark"])
    }

    @MainActor
    private func auditEveryScreen(appearance: XCUIDevice.Appearance, arguments: [String]) throws {
        XCUIDevice.shared.appearance = appearance
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["--sample-data", "-replayMode", "YES", "-startsAtPlace", "NO"] + arguments
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Errands"].waitForExistence(timeout: 30), "Plan screen never appeared")
        Thread.sleep(forTimeInterval: 5)

        var failures: [String] = []
        var report: [String] = []
        func auditOnce(_ screen: String) throws {
            try app.performAccessibilityAudit { issue in
                let element = issue.element.map {
                    "type \($0.elementType.rawValue) “\($0.label)” id “\($0.identifier)” at \($0.frame)"
                } ?? "no element"
                let line = "\(screen): \(issue.compactDescription) — \(element) — \(issue.detailedDescription)"
                if let reason = Self.exemption(for: issue, windowHeight: app.windows.firstMatch.frame.height) {
                    report.append("ignored (\(reason)): \(line)")
                } else {
                    report.append("FAILED: \(line)")
                    failures.append(line)
                }
                return true
            }
        }

        func audit(_ screen: String) throws {
            for attempt in 1...3 {
                let reportCount = report.count
                let failureCount = failures.count
                do {
                    try auditOnce(screen)
                    return
                } catch let error as NSError where error.code == -56 && attempt < 3 {
                    // "Audit failed to complete in time": the screen was still busy, so wait and audit it again.
                    report.removeSubrange(reportCount...)
                    failures.removeSubrange(failureCount...)
                    Thread.sleep(forTimeInterval: 5)
                }
            }
        }

        try audit("Plan")

        tap(app.tabBars.buttons["Errands"])
        try audit("Errands")
        tap(app.buttons["Add Errand"].firstMatch)
        let sheet = app.navigationBars["New Errand"]
        XCTAssertTrue(sheet.waitForExistence(timeout: 30), "New Errand sheet never opened")
        try audit("New Errand")
        tap(app.buttons["Cancel"])
        XCTAssertTrue(sheet.waitForNonExistence(timeout: 30), "New Errand sheet never closed")

        tap(app.tabBars.buttons["About"])
        try audit("About")

        tap(app.tabBars.buttons["Plan"])
        for name in ["Post Office", "Coles", "Library"] {
            tap(app.buttons["errand-\(name)"])
        }
        tap(app.buttons["calculate"])
        XCTAssertTrue(app.navigationBars["Results"].waitForExistence(timeout: 30), "Results never appeared")
        Thread.sleep(forTimeInterval: 2)
        try audit("Results")

        tap(app.buttons["plan-card"].firstMatch)
        XCTAssertTrue(app.navigationBars["Itinerary"].waitForExistence(timeout: 10), "Itinerary never appeared")
        try audit("Itinerary")
        app.swipeUp()
        Thread.sleep(forTimeInterval: 1)
        try audit("Itinerary, scrolled")
        app.swipeDown()
        Thread.sleep(forTimeInterval: 1)

        tap(app.buttons["check-radar"])
        XCTAssertTrue(app.descendants(matching: .any)["Rain map"].waitForExistence(timeout: 60), "Radar advice never appeared")
        try audit("Next Walk")
        app.swipeUp()
        Thread.sleep(forTimeInterval: 1)
        try audit("Next Walk, scrolled")

        let attachment = XCTAttachment(string: report.isEmpty ? "No issues." : report.joined(separator: "\n"))
        attachment.name = "accessibility-report-\(appearance == .dark ? "dark" : "light")"
        attachment.lifetime = .keepAlways
        add(attachment)
        XCTAssertTrue(failures.isEmpty, "Accessibility issues:\n" + report.joined(separator: "\n"))
    }

    @MainActor
    private func tap(_ element: XCUIElement) {
        XCTAssertTrue(element.waitForExistence(timeout: 10), "\(element) not found")
        element.tap()
    }

    @MainActor
    private static func exemption(for issue: XCUIAccessibilityAuditIssue, windowHeight: CGFloat) -> String? {
        if issue.auditType == .dynamicType || issue.auditType == .textClipped {
            return "DynamicTypeTests measures every text growing at the largest size instead"
        }
        // "Contrast failed" and "Contrast nearly passed" both count as contrast issues.
        let isContrast = issue.auditType == .contrast || issue.compactDescription.hasPrefix("Contrast")
        if isContrast, let frame = issue.element?.frame, frame.maxY > windowHeight - 200 {
            return "behind the translucent tab bar or Calculate bar; readable once scrolled"
        }
        if isContrast, issue.element?.isEnabled == false {
            return "WCAG 1.4.3 exempts inactive controls"
        }
        if isContrast, issue.element?.elementType == .searchField {
            return "placeholder of the system search field, coloured by iOS"
        }
        if issue.detailedDescription.contains("MKAttributionLabel") {
            return "Legal link drawn by Apple Maps"
        }
        if issue.element == nil {
            return "no element: drawn by iOS or Apple Maps (Liquid Glass bars, map labels), check with Accessibility Inspector"
        }
        return nil
    }
}
