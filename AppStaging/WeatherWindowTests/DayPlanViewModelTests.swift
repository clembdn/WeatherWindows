import ForecastKit
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

    @Test func defaultWindowStartsAtTheNextFiveMinutesAndLastsTwoHours() {
        let model = DayPlanViewModel(now: at(14, 2))

        #expect(model.windowStart == at(14, 5))
        #expect(model.windowEnd == at(16, 5))
    }

    @Test func refusesAFifthErrand() {
        let model = DayPlanViewModel()
        let errands = insertErrands(["Post", "Coles", "Library", "Gym", "Chemist"])

        errands.forEach(model.toggle)

        #expect(model.selectedErrandIDs.count == 4)
        #expect(model.selectionMessage != nil)
        #expect(!model.isSelected(errands[4]))
    }

    @Test func calculatesAFrontierWithFakeServices() async throws {
        let model = morningModel()
        let errands = insertErrands(["Post", "Coles"])

        await model.calculate(errands: errands, services: fakeServices())

        let result = try #require(model.result)
        #expect(!result.frontier.isEmpty)
        #expect(result.start.name == "Current Location")
        #expect(model.progress == nil)
    }

    @Test func reportsAnOfflineForecast() async {
        let model = morningModel()
        var services = fakeServices()
        services.hourlyForecast = { _ in throw URLError(.notConnectedToInternet) }

        await model.calculate(errands: insertErrands(["Post"]), services: services)

        guard case .failed(let error) = model.state else {
            Issue.record("Expected a failure, got \(model.state)")
            return
        }
        #expect(error == .offline)
    }

    @Test func switchesToAChosenStartWhenLocationIsDenied() async {
        let model = morningModel()
        var services = fakeServices()
        services.currentLocation = { throw ServiceError.locationDenied }

        await model.calculate(errands: insertErrands(["Post"]), services: services)

        #expect(model.startChoice == .place)
        #expect(!model.canCalculate(selectedCount: 1))
    }

    @Test func explainsWhichErrandClosesTooEarly() async throws {
        let model = DayPlanViewModel(now: at(14, 0))
        let errand = SavedErrand(draft: ErrandDraft(
            name: "Post", place: place, durationMinutes: 10, openingMinute: 9 * 60, closingMinute: 13 * 60
        ))
        context.insert(errand)

        await model.calculate(errands: [errand], services: fakeServices())

        let result = try #require(model.result)
        guard case .infeasible(let reason) = result.outcome else {
            Issue.record("Expected no feasible plan")
            return
        }
        #expect(PlanText.reason(reason).hasPrefix("Post closes at 13:00"))
    }

    @Test func savesTheChosenScheduleWithCopiedStops() async throws {
        let model = morningModel()
        await model.calculate(errands: insertErrands(["Post", "Coles"]), services: fakeServices())
        let result = try #require(model.result)
        let schedule = try #require(result.fastest)

        try model.save(schedule, from: result, in: context)

        let plan = try #require(try context.fetch(FetchDescriptor<DayPlan>()).first)
        #expect(plan.orderedStops.map(\.name) == schedule.order.map(\.name))
        #expect(plan.orderedStops.allSatisfy { $0.errand != nil && $0.arrival != nil })
        #expect(plan.departure == schedule.departure)
    }

    // MARK: Helpers

    private let place = Place(name: "Melbourne Central", location: GeoPoint(latitude: -37.8102, longitude: 144.9628))

    private func at(_ hour: Int, _ minute: Int) -> Date {
        AppClock.calendar.date(from: DateComponents(year: 2026, month: 10, day: 14, hour: hour, minute: minute))!
    }

    private func morningModel() -> DayPlanViewModel {
        DayPlanViewModel(now: at(10, 0))
    }

    private func insertErrands(_ names: [String]) -> [SavedErrand] {
        names.map { name in
            let errand = SavedErrand(draft: ErrandDraft(
                name: name, place: place, durationMinutes: 10, openingMinute: 8 * 60, closingMinute: 20 * 60
            ))
            context.insert(errand)
            return errand
        }
    }

    /// Ten minutes between any two places and a dry day.
    private func fakeServices() -> PlanServices {
        PlanServices(
            currentLocation: { .melbourneCBD },
            walkingTimes: { _, _, stops in
                var matrix: [Node: [Node: TimeInterval]] = [:]
                for (from, to) in WalkingMatrixBuilder.edges(for: stops) {
                    matrix[from, default: [:]][to] = 600
                }
                return matrix
            },
            hourlyForecast: { _ in [] }
        )
    }
}

struct PlanTextTests {
    @Test func describesRain() {
        #expect(PlanText.rain(0.2) == "Dry")
        #expect(PlanText.rain(0.6) == "Up to ~1 min of rain")
        #expect(PlanText.rain(3.6) == "Up to ~4 min of rain")
    }

    @Test func describesDurations() {
        #expect(PlanText.duration(45 * 60) == "45 min")
        #expect(PlanText.duration(65 * 60) == "1 h 05 min")
    }
}
