import Foundation
import SwiftData
import Testing
import WeatherWindowCore
@testable import WeatherWindow

struct ErrandStoreTests {
    let container: ModelContainer
    let store: ErrandStore

    init() throws {
        container = try ModelContainer(
            for: SavedErrand.self, DayPlan.self, PlannedStop.self, CachedWalkingTime.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        store = ErrandStore(context: container.mainContext)
    }

    @Test func addsErrand() throws {
        guard case .added = store.add(errand(named: "Coles")) else {
            Issue.record("Expected the errand to be added")
            return
        }
        let errands = try container.mainContext.fetch(FetchDescriptor<SavedErrand>())
        #expect(errands.map(\.name) == ["Coles"])
        #expect(errands.first?.normalizedName == "coles")
    }

    @Test func rejectsDuplicateNameIgnoringCaseAccentsAndSpaces() {
        _ = store.add(errand(named: "Café Coles"))

        guard case .duplicateName = store.add(errand(named: "  cafe coles ")) else {
            Issue.record("Expected a duplicate-name result")
            return
        }
    }

    @Test func deletingPlanDeletesItsStops() throws {
        let context = container.mainContext
        let post = errand(named: "Post")
        _ = store.add(post)
        let plan = try savedPlan(visiting: post)

        context.delete(plan)
        try context.save()

        #expect(try context.fetchCount(FetchDescriptor<PlannedStop>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<SavedErrand>()) == 1)
    }

    @Test func deletingErrandKeepsThePlannedCopy() throws {
        let library = errand(named: "Library")
        _ = store.add(library)
        _ = try savedPlan(visiting: library)

        store.delete([library])

        let stop = try #require(try container.mainContext.fetch(FetchDescriptor<PlannedStop>()).first)
        #expect(stop.name == "Library")
        #expect(stop.errand == nil)
    }

    private let place = Place(name: "Melbourne Central", location: GeoPoint(latitude: -37.8102, longitude: 144.9628))

    private func errand(named name: String) -> SavedErrand {
        SavedErrand(name: name, place: place, durationMinutes: 15, openingMinute: 9 * 60, closingMinute: 17 * 60)
    }

    private func savedPlan(visiting errand: SavedErrand) throws -> DayPlan {
        let plan = DayPlan(departure: .now, returnTime: .now.addingTimeInterval(3600), robustExposure: 0, start: place, end: nil)
        container.mainContext.insert(plan)
        plan.stops.append(PlannedStop(errand: errand, rank: 0, arrival: .now, departure: .now))
        try container.mainContext.save()
        return plan
    }
}
