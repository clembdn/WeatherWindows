import Foundation
import SwiftData
import WeatherWindowCore

/// Launch arguments used by UI tests and screenshots.
nonisolated enum LaunchOption {
    /// Starts with an in-memory store filled with four real Melbourne errands.
    static let sampleData = "--sample-data"

    static var usesSampleData: Bool {
        ProcessInfo.processInfo.arguments.contains(sampleData)
    }
}

/// Four real places around the CBD, for UI tests and the demo.
enum SampleData {
    static let errands: [ErrandDraft] = [
        ErrandDraft(
            name: "Post Office",
            place: Place(name: "Australia Post Melbourne GPO", location: GeoPoint(latitude: -37.8131, longitude: 144.9637)),
            durationMinutes: 10, openingMinute: 9 * 60, closingMinute: 17 * 60
        ),
        ErrandDraft(
            name: "Coles",
            place: Place(name: "Coles Melbourne Central", location: GeoPoint(latitude: -37.8102, longitude: 144.9628)),
            durationMinutes: 20, openingMinute: 7 * 60, closingMinute: 22 * 60
        ),
        ErrandDraft(
            name: "Library",
            place: Place(name: "State Library Victoria", location: GeoPoint(latitude: -37.8098, longitude: 144.9652)),
            durationMinutes: 45, openingMinute: 10 * 60, closingMinute: 18 * 60
        ),
        ErrandDraft(
            name: "Gym",
            place: Place(name: "Fitness First Bourke Street", location: GeoPoint(latitude: -37.8146, longitude: 144.9655)),
            durationMinutes: 60, openingMinute: 6 * 60, closingMinute: 22 * 60
        )
    ]

    static func insert(into context: ModelContext) {
        for draft in errands {
            context.insert(SavedErrand(draft: draft))
        }
    }
}
