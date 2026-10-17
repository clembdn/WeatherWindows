//
//  WeatherWindowApp.swift
//  WeatherWindow
//
//  Created by Clement Boudon on 7/10/2026.
//

import SwiftData
import SwiftUI

@main
struct WeatherWindowApp: App {
    private let container: ModelContainer
    @State private var errandStore: ErrandStore
    @State private var notificationService = NotificationService()
    @AppStorage("appearance") private var appearance = "system"

    private var colorScheme: ColorScheme? {
        if let forced = LaunchOption.forcedColorScheme {
            return forced
        }
        switch appearance {
        case "light":
            return .light
        case "dark":
            return .dark
        default:
            return nil
        }
    }

    init() {
        do {
            container = try ModelContainer(
                for: SavedErrand.self, DayPlan.self, PlannedStop.self, CachedWalkingTime.self, VerificationScore.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: LaunchOption.usesSampleData)
            )
        } catch {
            fatalError("The WeatherWindow database could not be opened: \(error)")
        }
        if LaunchOption.usesSampleData {
            SampleData.insert(into: container.mainContext)
        }
        _errandStore = State(initialValue: ErrandStore(context: container.mainContext))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(errandStore)
                .environment(notificationService)
                .preferredColorScheme(colorScheme)
        }
        .modelContainer(container)
    }
}
