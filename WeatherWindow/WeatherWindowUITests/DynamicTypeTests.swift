//
//  DynamicTypeTests.swift
//  WeatherWindowUITests
//
//  Created by Clement Boudon on 28/10/2026.
//

import UIKit
import XCTest

/// Measures every text on Results, Itinerary and Next Walk at the default size and at the largest
/// accessibility size: a text whose height doesn't grow ignores Dynamic Type.
nonisolated final class DynamicTypeTests: XCTestCase {
    private static let largest = ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]

    @MainActor
    func testEveryTextGrowsAtTheLargestSize() {
        let normal = measureTexts(arguments: [], capturesAs: nil)
        let large = measureTexts(arguments: Self.largest, capturesAs: "largest-text")

        var report: [String] = []
        var stuck: [String] = []
        for (key, height) in normal.sorted(by: { $0.key < $1.key }) {
            guard let largeHeight = large[key] else {
                report.append("not found at the largest size: \(key)")
                continue
            }
            let line = "\(key): \(Int(height)) → \(Int(largeHeight)) pt"
            if key.contains(": Replay mode") {
                report.append(line + " (replay banner, capped at accessibility1 on purpose)")
                continue
            }
            report.append(line)
            if largeHeight < height * 1.2 {
                stuck.append(line)
            }
        }
        for line in report {
            XCTContext.runActivity(named: "Dynamic Type · \(line)") { _ in }
        }
        let attachment = XCTAttachment(string: report.joined(separator: "\n"))
        attachment.name = "dynamic-type-report"
        attachment.lifetime = .keepAlways
        add(attachment)
        XCTAssertTrue(stuck.isEmpty, "Text that doesn't grow at the largest size:\n" + stuck.joined(separator: "\n"))
    }

    /// Text heights by "screen: label", read while scrolling through each screen.
    @MainActor
    private func measureTexts(arguments: [String], capturesAs prefix: String?) -> [String: CGFloat] {
        XCUIDevice.shared.appearance = .light
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["--sample-data", "-replayMode", "YES", "-startsAtPlace", "NO"] + arguments
        app.launch()
        var heights: [String: CGFloat] = [:]

        tap(app.tabBars.buttons["Plan"], in: app)
        for name in ["Coles", "Library", "Post Office"] {
            tap(app.buttons["errand-\(name)"], in: app)
        }
        app.buttons["calculate"].tap()
        XCTAssertTrue(app.navigationBars["Results"].waitForExistence(timeout: 30), "Results never appeared")
        Thread.sleep(forTimeInterval: 2)
        collectTexts("Results", in: app, into: &heights, capturesAs: prefix.map { "\($0)-results" })
        scrollToTop(app)

        tap(app.buttons["plan-card"].firstMatch, in: app)
        XCTAssertTrue(app.navigationBars["Itinerary"].waitForExistence(timeout: 10), "Itinerary never appeared")
        Thread.sleep(forTimeInterval: 2)
        collectTexts("Itinerary", in: app, into: &heights, capturesAs: prefix.map { "\($0)-itinerary" })
        scrollToTop(app)

        tap(app.buttons["check-radar"], in: app)
        XCTAssertTrue(app.navigationBars["Next Walk"].waitForExistence(timeout: 10), "Next Walk never appeared")
        XCTAssertTrue(app.staticTexts["Checking the radar…"].waitForNonExistence(timeout: 60), "Radar never loaded")
        Thread.sleep(forTimeInterval: 2)
        collectTexts("Next Walk", in: app, into: &heights, capturesAs: prefix.map { "\($0)-next-walk" })

        app.terminate()
        return heights
    }

    /// Scrolls a page at a time until the screen stops moving, so long screens are measured to the end.
    @MainActor
    private func collectTexts(_ screen: String, in app: XCUIApplication, into heights: inout [String: CGFloat],
                              capturesAs prefix: String?) {
        var lastPage: [String] = []
        for page in 1...30 {
            if let prefix {
                capture(prefix + "-\(page)")
            }
            let texts = visibleTexts(in: app)
            for (label, frame) in texts where heights["\(screen): \(label)"] == nil {
                heights["\(screen): \(label)"] = frame.height
            }
            let thisPage = positions(of: texts)
            if thisPage == lastPage {
                break
            }
            lastPage = thisPage
            scroll(app, down: true)
        }
    }

    /// Texts and buttons on screen, outside the navigation and tab bars, which iOS sizes itself.
    /// A text taller than the screen counts too: its frame keeps its full height.
    @MainActor
    private func visibleTexts(in app: XCUIApplication) -> [(label: String, frame: CGRect)] {
        guard let root = try? app.snapshot() else { return [] }
        let window = root.frame
        var found: [(label: String, frame: CGRect)] = []
        func visit(_ node: XCUIElementSnapshot, inBar: Bool) {
            let isBar = inBar || node.elementType == .navigationBar || node.elementType == .tabBar
            let isText = node.elementType == .staticText || node.elementType == .button
            if !isBar, isText, !node.label.isEmpty, node.frame.height > 0, window.intersects(node.frame) {
                found.append((label: node.label, frame: node.frame))
            }
            for child in node.children {
                visit(child, inBar: isBar)
            }
        }
        visit(root, inBar: false)
        return found
    }

    /// Where each text sits: the same list twice in a row means the scroll reached the end.
    private func positions(of texts: [(label: String, frame: CGRect)]) -> [String] {
        texts.map { "\($0.label) \(Int($0.frame.minY))" }
    }

    /// Drags along the right margin, outside the maps, so the list scrolls instead of the map.
    @MainActor
    private func scroll(_ app: XCUIApplication, down: Bool) {
        let top = app.coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: 0.3))
        let bottom = app.coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: 0.75))
        if down {
            bottom.press(forDuration: 0.05, thenDragTo: top, withVelocity: .default, thenHoldForDuration: 0.1)
        } else {
            top.press(forDuration: 0.05, thenDragTo: bottom, withVelocity: .fast, thenHoldForDuration: 0.1)
        }
        Thread.sleep(forTimeInterval: 1)
    }

    @MainActor
    private func scrollToTop(_ app: XCUIApplication) {
        var lastPage: [String] = []
        for _ in 1...30 {
            scroll(app, down: false)
            let thisPage = positions(of: visibleTexts(in: app))
            if thisPage == lastPage {
                break
            }
            lastPage = thisPage
        }
    }

    /// Scrolls down until the element can be tapped, since big text pushes it off screen.
    @MainActor
    private func tap(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 1...12 where !(element.exists && element.isHittable) {
            scroll(app, down: true)
        }
        XCTAssertTrue(element.waitForExistence(timeout: 10), "\(element) not found")
        element.tap()
    }

    @MainActor
    private func capture(_ name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        printThumbnail(screenshot.image, name: name)
    }

    /// Temporary: prints a small JPEG of the screen in the log, to check the layout without the artifact.
    @MainActor
    private func printThumbnail(_ image: UIImage, name: String) {
        let size = CGSize(width: 300, height: image.size.height * 300 / image.size.width)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let small = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        guard let text = small.jpegData(compressionQuality: 0.55)?.base64EncodedString() else { return }
        var start = text.startIndex
        var part = 0
        while start < text.endIndex {
            let end = text.index(start, offsetBy: 2000, limitedBy: text.endIndex) ?? text.endIndex
            XCTContext.runActivity(named: "THUMB \(name) \(part) \(text[start..<end])") { _ in }
            start = end
            part += 1
        }
    }
}
