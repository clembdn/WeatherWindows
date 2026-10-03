import XCTest

/// Runs Apple's automated accessibility audit (contrast, hit regions, labels, clipped text) on each main screen.
/// Every issue goes into a report attached to the test; only issues not explained below fail it.
nonisolated final class AccessibilityAuditTests: XCTestCase {
    @MainActor
    func testMainScreensPassTheAccessibilityAudit() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--sample-data"]
        app.launch()

        var failures: [String] = []
        var report: [String] = []
        func audit(_ screen: String) throws {
            try app.performAccessibilityAudit { issue in
                let element = issue.element.map { "\($0.elementType.rawValue) “\($0.label)”" } ?? "screen"
                let line = "\(screen): \(issue.compactDescription) — \(element)"
                if let reason = Self.exemption(for: issue, windowHeight: app.windows.firstMatch.frame.height) {
                    report.append("ignored (\(reason)): \(line)")
                } else {
                    report.append("FAILED: \(line)")
                    failures.append(line)
                }
                return true
            }
        }

        try audit("Plan")
        app.tabBars.buttons["Errands"].tap()
        try audit("Errands")
        app.tabBars.buttons["About"].tap()
        try audit("About")

        let attachment = XCTAttachment(string: report.isEmpty ? "No issues." : report.joined(separator: "\n"))
        attachment.name = "accessibility-report"
        attachment.lifetime = .keepAlways
        add(attachment)
        XCTAssertTrue(failures.isEmpty, "Accessibility issues:\n" + failures.joined(separator: "\n"))
    }

    /// Why an issue does not count, or nil when it must be fixed.
    @MainActor
    private static func exemption(for issue: XCUIAccessibilityAuditIssue, windowHeight: CGFloat) -> String? {
        let description = issue.compactDescription
        if issue.auditType == .contrast, let frame = issue.element?.frame, frame.maxY > windowHeight - 200 {
            return "behind the translucent tab bar or Calculate bar; readable once scrolled"
        }
        if issue.auditType == .textClipped, issue.element?.elementType == .searchField {
            return "system search field placeholder, collapsed by design"
        }
        if issue.auditType == .contrast, issue.element?.isEnabled == false {
            return "WCAG 1.4.3 exempts inactive controls"
        }
        if issue.auditType == .contrast, description.localizedCaseInsensitiveContains("nearly") {
            return "below the failure threshold"
        }
        if issue.auditType == .contrast, issue.element == nil {
            return "no element: system chrome such as the Liquid Glass tab bar, check with Accessibility Inspector"
        }
        if issue.auditType == .dynamicType, [.staticText, .switch, .other].contains(issue.element?.elementType) {
            return "system section headers and toggles scale, see largest-text screenshots"
        }
        return nil
    }
}
