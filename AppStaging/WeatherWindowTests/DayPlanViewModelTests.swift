import Foundation
import SolverKit
import SwiftData
import Testing
import WeatherWindowCore
@testable import WeatherWindow

struct DayPlanViewModelTests {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }

    init() throws {
        container = try ModelContainer(
            for: SavedErrand.self, DayPlan.self, PlannedStop.self, CachedWalkingTime.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    @Test func refusesAFifthErrand() {
        let model = morningModel()
        let errands = insertErrands(["Post", "Coles", "Library", "Gym", "Chemist"])

        for errand in errands {
            model.toggle(errand)
        }

        #expect(model.selectedIDs.count == 4)
        #expect(model.selectionMessage != nil)
        #expect(!model.selectedIDs.contains(errands[4].id))
    }

    @Test func calculatesAFrontierWithFakeServices() async throws {
        let model = morningModel()

        await model.calculate(errands: insertErrands(["Post", "Coles"]), data: FakeData())

        let result = try #require(model.result)
        #expect(!result.frontier.isEmpty)
        #expect(result.start.name == "Current Location")
        #expect(model.progress == nil)
    }

    @Test func reportsAnOfflineForecast() async {
        let model = morningModel()
        var data = FakeData()
        data.forecastError = URLError(.notConnectedToInternet)

        await model.calculate(errands: insertErrands(["Post"]), data: data)

        guard case .failed(let error) = model.state else {
            Issue.record("Expected a failure, got \(model.state)")
            return
        }
        #expect(error == .offline)
    }

    @Test func cancellationIsNotReportedAsAnError() async {
        let model = morningModel()
        var data = FakeData()
        data.forecastError = CancellationError()

        await model.calculate(errands: insertErrands(["Post"]), data: data)

        guard case .idle = model.state else {
            Issue.record("Expected no error after a cancellation, got \(model.state)")
            return
        }
    }

    @Test func switchesToAChosenStartWhenLocationIsDenied() async {
        let model = morningModel()
        var data = FakeData()
        data.locationError = ServiceError.locationDenied

        await model.calculate(errands: insertErrands(["Post"]), data: data)

        #expect(!model.startsAtCurrentLocation)
        #expect(!model.canCalculate(selectedCount: 1))
    }

    @Test func explainsWhichErrandClosesTooEarly() async throws {
        let model = DayPlanViewModel(now: at(14, 0), defaults: emptySettings())
        let post = SavedErrand(name: "Post", place: place, durationMinutes: 10, openingMinute: 9 * 60, closingMinute: 13 * 60)
        context.insert(post)

        await model.calculate(errands: [post], data: FakeData())

        let result = try #require(model.result)
        guard case .infeasible(let reason) = result.outcome else {
            Issue.record("Expected no feasible plan")
            return
        }
        #expect(PlanText.reason(reason).hasPrefix("Post closes at 13:00"))
    }

    @Test func savesTheChosenScheduleWithCopiedStops() async throws {
        let model = morningModel()
        await model.calculate(errands: insertErrands(["Post", "Coles"]), data: FakeData())
        let result = try #require(model.result)
        let schedule = try #require(result.fastest)

        try result.save(schedule, in: context)

        let plan = try #require(try context.fetch(FetchDescriptor<DayPlan>()).first)
        #expect(plan.orderedStops.map(\.name) == schedule.order.map(\.name))
        #expect(plan.orderedStops.allSatisfy { $0.errand != nil })
        #expect(plan.departure == schedule.departure)
    }

    // MARK: Helpers

    private let place = Place(name: "Melbourne Central", location: GeoPoint(latitude: -37.8102, longitude: 144.9628))

    // A Melbourne time on Wednesday 14 October 2026.
    private func at(_ hour: Int, _ minute: Int) -> Date {
        Melbourne.calendar.date(from: DateComponents(year: 2026, month: 10, day: 14, hour: hour, minute: minute))!
    }

    private func morningModel() -> DayPlanViewModel {
        DayPlanViewModel(now: at(10, 0), defaults: emptySettings())
    }

    // New empty settings for each test, so a start place saved by the app or by another test never leaks in.
    private func emptySettings() -> UserDefaults {
        UserDefaults(suiteName: "DayPlanViewModelTests-\(UUID().uuidString)")!
    }

    private func insertErrands(_ names: [String]) -> [SavedErrand] {
        var errands: [SavedErrand] = []
        for name in names {
            let errand = SavedErrand(name: name, place: place, durationMinutes: 10, openingMinute: 8 * 60, closingMinute: 20 * 60)
            context.insert(errand)
            errands.append(errand)
        }
        return errands
    }
}
