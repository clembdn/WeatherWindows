//
//  SampleData.swift
//  WeatherWindow
//
//  Created by Clement Boudon on 7/10/2026.
//

import Foundation
import SwiftData
import SwiftUI

enum LaunchOption {
    static var usesSampleData: Bool {
        ProcessInfo.processInfo.arguments.contains("--sample-data")
    }

    static var forcedColorScheme: ColorScheme? {
        ProcessInfo.processInfo.arguments.contains("--dark") ? .dark : nil
    }
}

enum SampleData {
    static func insert(into context: ModelContext) {
        context.insert(SavedErrand(
            name: "Post Office",
            place: Place(name: "Australia Post Melbourne GPO", location: GeoPoint(latitude: -37.8131, longitude: 144.9637)),
            durationMinutes: 10, openingMinute: 9 * 60, closingMinute: 17 * 60
        ))
        context.insert(SavedErrand(
            name: "Coles",
            place: Place(name: "Coles Melbourne Central", location: GeoPoint(latitude: -37.8102, longitude: 144.9628)),
            durationMinutes: 20, openingMinute: 7 * 60, closingMinute: 22 * 60
        ))
        context.insert(SavedErrand(
            name: "Library",
            place: Place(name: "State Library Victoria", location: GeoPoint(latitude: -37.8098, longitude: 144.9652)),
            durationMinutes: 45, openingMinute: 10 * 60, closingMinute: 18 * 60
        ))
        context.insert(SavedErrand(
            name: "Gym",
            place: Place(name: "Fitness First Bourke Street", location: GeoPoint(latitude: -37.8146, longitude: 144.9655)),
            durationMinutes: 60, openingMinute: 6 * 60, closingMinute: 22 * 60
        ))
    }
}
