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

    @Test func forgetsADeletedErrand() {
        let model = morningModel()
        let errands = insertErrands(["Post", "Coles", "Library", "Gym", "Chemist"])
        for errand in errands {
            model.toggle(errand)
        }

        // "Gym" is deleted in the Errands tab, which frees a place for "Chemist".
        model.keepSelected(onlyAmong: [errands[0].id, errands[1].id, errands[2].id, errands[4].id])
        #expect(model.selectionMessage == nil)
        model.toggle(errands[4])

        #expect(model.selectedIDs.count == 4)
        #expect(model.selectedIDs.contains(errands[4].id))
        #expect(!model.selectedIDs.contains(errands[3].id))
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

    @Test func savesTheSamePlanOnlyOnce() async throws {
        let model = morningModel()
        await model.calculate(errands: insertErrands(["Post", "Coles"]), data: FakeData())
        let result = try #require(model.result)
        let schedule = try #require(result.fastest)

        try result.save(schedule, in: context)
        try result.save(schedule, in: context)

        #expect(try context.fetchCount(FetchDescriptor<DayPlan>()) == 1)
        #expect(result.isSaved(schedule, in: context))
    }

    @Test func learnsTheUsualTradeOff() async throws {
        let result = try await rainyMorningResult()
        let fastest = try #require(result.fastest)
        let driest = try #require(result.driest)
        #expect(result.frontier.count > 2)

        #expect(result.tradeOff(of: fastest) == 0)
        #expect(result.tradeOff(of: driest) == 1)
        #expect(result.usualChoice(savedTradeOffs: [1]) == nil)
        #expect(result.usualChoice(savedTradeOffs: [1, 1])?.id == driest.id)
        #expect(result.usualChoice(savedTradeOffs: [0, 0, 0])?.id == fastest.id)
    }

    @Test func sharesThePlanAsText() async throws {
        let result = try await rainyMorningResult()
        let schedule = try #require(result.driest)

        let text = result.shareText(for: schedule)

        #expect(text.hasPrefix("Leave Current Location at"))
        #expect(text.contains("1. Post"))
        #expect(text.contains("Back at Current Location"))
    }

    @Test func scoresWithTheEnsembleWhenItIsAvailable() async throws {
        let model = morningModel()
        model.usesEnsemble = true
        var data = FakeData()
        let json = """
            {"hourly": {"time": [1791939600], "precipitation": [0], "precipitation_member01": [2]}}
            """
        data.ensemble = try JSONDecoder().decode(OpenMeteoEnsembleResponse.self, from: Data(json.utf8))

        await model.calculate(errands: insertErrands(["Post"]), data: data)
        let withEnsemble = try #require(model.result)
        #expect(withEnsemble.usesEnsemble)
        #expect(withEnsemble.scenarios.count == 5)

        // Offline ensemble: the shifted forecast is used instead, and the plan is still calculated.
        data.ensemble = nil
        await model.calculate(errands: insertErrands(["Coles"]), data: data)
        let withoutEnsemble = try #require(model.result)
        #expect(!withoutEnsemble.usesEnsemble)
        #expect(withoutEnsemble.scenarios.count == 5)
    }

    // MARK: Helpers

    // Rain from 10:00 to 11:00: leaving at 10:00 is fastest but wet, leaving later is slower but drier.
    private func rainyMorningResult() async throws -> PlanResult {
        let model = morningModel()
        var data = FakeData()
        data.forecast = [WeatherSample(time: at(11, 0), precipitationProbability: 100, precipitation: 1)]
        await model.calculate(errands: insertErrands(["Post"]), data: data)
        return try #require(model.result)
    }

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
