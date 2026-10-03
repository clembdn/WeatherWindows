import XCTest

/// Runs Apple's automated accessibility audit (contrast, hit regions, labels, clipped text) on each main screen.
nonisolated final class AccessibilityAuditTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = true
    }

    @MainActor
    func testMainScreensPassTheAccessibilityAudit() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--sample-data"]
        app.launch()

        var issues: [String] = []
        func audit(_ screen: String) throws {
            try app.performAccessibilityAudit { issue in
                let element = issue.element.map { "\($0.elementType.rawValue) “\($0.label)”" } ?? "screen"
                issues.append("\(screen): \(issue.compactDescription) — \(element)")
                return true
            }
        }

        try audit("Plan")
        app.tabBars.buttons["Errands"].tap()
        try audit("Errands")
        app.tabBars.buttons["About"].tap()
        try audit("About")

        XCTAssertTrue(issues.isEmpty, "Accessibility issues:\n" + issues.joined(separator: "\n"))
    }
}
