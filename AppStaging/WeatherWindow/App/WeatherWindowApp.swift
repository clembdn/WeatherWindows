import SwiftData
import SwiftUI

@main
struct WeatherWindowApp: App {
    private let container: ModelContainer
    @State private var errandStore: ErrandStore
    @State private var locationService = LocationService()

    init() {
        do {
            container = try ModelContainer(for: SavedErrand.self, DayPlan.self, PlannedStop.self, CachedWalkingTime.self)
        } catch {
            fatalError("The WeatherWindow database could not be opened: \(error)")
        }
        _errandStore = State(initialValue: ErrandStore(context: container.mainContext))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(errandStore)
                .environment(locationService)
        }
        .modelContainer(container)
    }
}
