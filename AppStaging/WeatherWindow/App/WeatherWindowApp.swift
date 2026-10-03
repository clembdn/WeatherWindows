import SwiftData
import SwiftUI

@main
struct WeatherWindowApp: App {
    private let container: ModelContainer
    @State private var errandStore: ErrandStore
    @State private var locationService = LocationService()
    @State private var notificationService = NotificationService()

    init() {
        do {
            container = try ModelContainer(
                for: SavedErrand.self, DayPlan.self, PlannedStop.self, CachedWalkingTime.self,
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
                .environment(locationService)
                .environment(notificationService)
                .preferredColorScheme(LaunchOption.forcedColorScheme)
        }
        .modelContainer(container)
    }
}
