import ForecastKit
import Foundation
import SolverKit
import SwiftData
import WeatherWindowCore

// Everything a calculation produced, kept together for the results, itinerary and map screens.
struct PlanResult {
    let outcome: SolveOutcome
    let start: Place
    let end: Place
    let endsAtStart: Bool
    let errands: [SavedErrand]
    let stops: [Stop]
    // The forecast and its four shifted copies the plans were scored against.
    let scenarios: [any RainField]
    let data: any PlanDataSource

    var frontier: [ScoredSchedule] {
        if case .frontier(let schedules) = outcome {
            return schedules
        }
        return []
    }

    // The frontier is sorted by duration: the first plan is the fastest, the last one the driest.
    var fastest: ScoredSchedule? { frontier.first }
    var driest: ScoredSchedule? { frontier.last }

    func name(of node: Node) -> String {
        switch node {
        case .start: start.name
        case .end: end.name
        case .stop(let id): stops.first { $0.id == id }?.name ?? "Errand"
        }
    }

    func location(of node: Node) -> GeoPoint {
        node.location(start: start.location, end: end.location, stops: stops)
    }

    // Stores the chosen schedule as a DayPlan whose stops copy today's values.
    func save(_ schedule: ScoredSchedule, in context: ModelContext) throws {
        let plan = DayPlan(departure: schedule.departure, returnTime: schedule.returnTime,
                           robustExposure: schedule.robustExposure, start: start, end: endsAtStart ? nil : end)
        context.insert(plan)
        for (rank, visit) in schedule.visits.enumerated() {
            if let errand = errands.first(where: { $0.id == visit.stop.id }) {
                plan.stops.append(PlannedStop(errand: errand, rank: rank, arrival: visit.arrival, departure: visit.departure))
            }
        }
        try context.save()
    }
}

// State and logic of the Plan tab: the choices, the "Calculate" steps, and the departure window.
@Observable
final class DayPlanViewModel {
    static let maxErrands = 4

    var selectedIDs: Set<UUID> = []
    var startsAtCurrentLocation = true {
        didSet { defaults.set(!startsAtCurrentLocation, forKey: "startsAtPlace") }
    }
    var startPlace: Place? {
        didSet { defaults.set(try? JSONEncoder().encode(startPlace), forKey: "startPlace") }
    }
    var endsAtStart = true
    var endPlace: Place?
    var windowStart: Date
    var windowEnd: Date

    private(set) var state = LoadState<PlanResult>.idle
    private(set) var progress: String?
    private(set) var selectionMessage: String?

    // The start place is remembered between launches; tests pass their own empty settings.
    @ObservationIgnored private let defaults: UserDefaults

    init(now: Date = .now, defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: "startPlace") {
            startPlace = try? JSONDecoder().decode(Place.self, from: data)
        }
        startsAtCurrentLocation = !defaults.bool(forKey: "startsAtPlace")
        let start = Self.nextFiveMinutes(after: now)
        windowStart = start
        windowEnd = start.addingTimeInterval(2 * 3600)
    }

    static func nextFiveMinutes(after date: Date) -> Date {
        let step: TimeInterval = 5 * 60
        return Date(timeIntervalSince1970: (date.timeIntervalSince1970 / step).rounded(.up) * step)
    }

    // From now to two hours later, starting at the next multiple of 5 minutes.
    func resetWindow(now: Date) {
        windowStart = Self.nextFiveMinutes(after: now)
        windowEnd = windowStart.addingTimeInterval(2 * 3600)
    }

    func toggle(_ errand: SavedErrand) {
        if selectedIDs.contains(errand.id) {
            selectedIDs.remove(errand.id)
            selectionMessage = nil
        } else if selectedIDs.count >= Self.maxErrands {
            selectionMessage = "You can plan up to \(Self.maxErrands) errands at once."
        } else {
            selectedIDs.insert(errand.id)
        }
    }

    var windowMessage: String? {
        if windowEnd < windowStart {
            return "The latest departure must be after the earliest one."
        }
        if windowEnd.timeIntervalSince(windowStart) > 4 * 3600 {
            return "Keep the departure window under 4 hours."
        }
        return nil
    }

    var isLoading: Bool {
        if case .loading = state {
            return true
        }
        return false
    }

    var result: PlanResult? {
        if case .loaded(let result) = state {
            return result
        }
        return nil
    }

    func canCalculate(selectedCount: Int) -> Bool {
        selectedCount >= 1 && selectedCount <= Self.maxErrands
            && windowMessage == nil
            && (startsAtCurrentLocation || startPlace != nil)
            && (endsAtStart || endPlace != nil)
            && !isLoading
    }

    // Position → walking times → forecast → solver, each step shown in `progress`.
    func calculate(errands: [SavedErrand], data: any PlanDataSource) async {
        guard windowMessage == nil else { return }
        state = .loading
        defer { progress = nil }

        do {
            progress = "Finding where you start…"
            let start: Place
            if startsAtCurrentLocation {
                start = Place(name: "Current Location", location: try await data.currentLocation())
            } else if let startPlace {
                start = startPlace
            } else {
                throw ServiceError.other("Choose a start place.")
            }
            let end = endsAtStart ? start : (endPlace ?? start)
            let stops = errands.map { $0.makeStop() }

            progress = "Getting walking times…"
            let walkingTimes = try await data.walkingTimes(start: start.location, end: end.location, stops: stops)

            progress = "Getting the forecast…"
            let centre = GeoPoint.centroid(of: stops.map(\.location)) ?? start.location
            let forecast = HourlyRainField(samples: try await data.hourlyForecast(at: centre))

            progress = "Comparing plans…"
            let request = PlanRequest(
                start: start.location,
                end: end.location,
                stops: stops,
                departureWindow: windowStart...windowEnd,
                walkingTimes: walkingTimes,
                timeZone: Melbourne.timeZone
            )
            let scenarios = ShiftedRainField.scenarios(around: forecast)
            let outcome = await Self.rankSchedules(request, scenarios: scenarios)

            state = .loaded(PlanResult(outcome: outcome, start: start, end: end, endsAtStart: endsAtStart,
                                       errands: errands, stops: stops, scenarios: scenarios, data: data))
        } catch {
            let serviceError = ServiceError(error)
            if serviceError == .cancelled {
                state = .idle
                return
            }
            if serviceError == .locationDenied || serviceError == .locationUnavailable {
                startsAtCurrentLocation = false
            }
            state = .failed(serviceError)
        }
    }

    // Up to 24 orders × 49 departures × 5 scenarios: the solver runs off the main thread.
    @concurrent
    private static func rankSchedules(_ request: PlanRequest, scenarios: [any RainField]) async -> SolveOutcome {
        ScheduleSolver().rankSchedules(for: request, scenarios: scenarios)
    }
}
