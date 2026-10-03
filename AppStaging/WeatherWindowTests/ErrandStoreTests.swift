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
        guard case .added = store.add(draft(named: "Coles")) else {
            Issue.record("Expected the errand to be added")
            return
        }
        let errands = try container.mainContext.fetch(FetchDescriptor<SavedErrand>())
        #expect(errands.map(\.name) == ["Coles"])
        #expect(errands.first?.normalizedName == "coles")
    }

    @Test func rejectsDuplicateNameIgnoringCaseAccentsAndSpaces() {
        _ = store.add(draft(named: "Café Coles"))

        guard case .duplicateName = store.add(draft(named: "  cafe coles ")) else {
            Issue.record("Expected a duplicate-name result")
            return
        }
    }

    @Test func deletingPlanDeletesItsStops() throws {
        let context = container.mainContext
        _ = store.add(draft(named: "Post"))
        let errand = try #require(try context.fetch(FetchDescriptor<SavedErrand>()).first)
        let plan = DayPlan(date: .now, start: place, end: nil, window: Date.now...Date.now.addingTimeInterval(7200))
        context.insert(plan)
        plan.stops.append(PlannedStop(copying: errand, rank: 0))
        try context.save()

        context.delete(plan)
        try context.save()

        #expect(try context.fetchCount(FetchDescriptor<PlannedStop>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<SavedErrand>()) == 1)
    }

    @Test func deletingErrandKeepsThePlannedCopy() throws {
        let context = container.mainContext
        _ = store.add(draft(named: "Library"))
        let errand = try #require(try context.fetch(FetchDescriptor<SavedErrand>()).first)
        let plan = DayPlan(date: .now, start: place, end: nil, window: Date.now...Date.now.addingTimeInterval(7200))
        context.insert(plan)
        plan.stops.append(PlannedStop(copying: errand, rank: 0))
        try context.save()

        store.delete([errand])

        let stop = try #require(try context.fetch(FetchDescriptor<PlannedStop>()).first)
        #expect(stop.name == "Library")
        #expect(stop.errand == nil)
    }

    private let place = Place(name: "Melbourne Central", location: GeoPoint(latitude: -37.8102, longitude: 144.9628))

    private func draft(named name: String) -> ErrandDraft {
        ErrandDraft(name: name, place: place, durationMinutes: 15, openingMinute: 9 * 60, closingMinute: 17 * 60)
    }
}
