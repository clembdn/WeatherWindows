import ForecastKit
import Foundation
import OSLog
import SolverKit
import SwiftData
import WeatherWindowCore

/// Where the day starts.
enum StartChoice: Hashable {
    case currentLocation
    case place
}

/// Screens pushed on the Plan tab's navigation stack.
enum PlanRoute: Hashable {
    case results
    case itinerary(scheduleID: String)
}

/// Everything a calculation produced, kept together for the results and itinerary screens.
struct PlanResult {
    let outcome: SolveOutcome
    let start: Place
    let end: Place
    let endsAtStart: Bool
    let window: ClosedRange<Date>
    let stops: [Stop]
    let errandIDs: [UUID: PersistentIdentifier]

    var frontier: [ScoredSchedule] {
        if case .frontier(let schedules) = outcome { return schedules }
        return []
    }

    /// Shortest duration: the first schedule of the frontier.
    var fastest: ScoredSchedule? { frontier.first }
    /// Least rain: the last schedule of the frontier.
    var driest: ScoredSchedule? { frontier.last }

    func schedule(withID id: String) -> ScoredSchedule? {
        frontier.first { $0.id == id }
    }

    func name(of node: Node) -> String {
        switch node {
        case .start: start.name
        case .end: end.name
        case .stop(let id): stops.first { $0.id == id }?.name ?? "Errand"
        }
    }
}

/// State and logic of the Plan tab: choices, the "Calculate" pipeline, and saving a plan.
@Observable
final class DayPlanViewModel {
    static let maxErrands = 4
    static let maxWindow: TimeInterval = 4 * 3600

    var selectedErrandIDs: Set<PersistentIdentifier> = []
    var startChoice = StartChoice.currentLocation
    var startPlace: Place?
    var endsAtStart = true
    var endPlace: Place?
    var windowStart: Date
    var windowEnd: Date

    private(set) var state = LoadState<PlanResult>.idle
    private(set) var progress: String?
    private(set) var selectionMessage: String?

    init(now: Date = .now) {
        let start = Self.nextFiveMinutes(after: now)
        windowStart = start
        windowEnd = start.addingTimeInterval(2 * 3600)
    }

    static func nextFiveMinutes(after date: Date) -> Date {
        let step: TimeInterval = 5 * 60
        return Date(timeIntervalSince1970: (date.timeIntervalSince1970 / step).rounded(.up) * step)
    }

    // MARK: Choices

    func isSelected(_ errand: SavedErrand) -> Bool {
        selectedErrandIDs.contains(errand.persistentModelID)
    }

    func toggle(_ errand: SavedErrand) {
        let id = errand.persistentModelID
        if selectedErrandIDs.remove(id) != nil {
            selectionMessage = nil
        } else if selectedErrandIDs.count >= Self.maxErrands {
            selectionMessage = "You can plan up to \(Self.maxErrands) errands at once."
        } else {
            selectedErrandIDs.insert(id)
        }
    }

    var windowMessage: String? {
        if windowEnd < windowStart { return "The latest departure must be after the earliest one." }
        if windowEnd.timeIntervalSince(windowStart) > Self.maxWindow { return "Keep the departure window under 4 hours." }
        return nil
    }

    var isLoading: Bool {
        if case .loading = state { return true }
        return false
    }

    var result: PlanResult? {
        if case .loaded(let result) = state { return result }
        return nil
    }

    func canCalculate(selectedCount: Int) -> Bool {
        (1...Self.maxErrands).contains(selectedCount)
            && windowMessage == nil
            && (startChoice == .currentLocation || startPlace != nil)
            && (endsAtStart || endPlace != nil)
            && !isLoading
    }

    // MARK: Calculate

    /// Position → walking times → forecast → solver, each step reported in `progress`.
    func calculate(errands: [SavedErrand], services: PlanServices) async {
        state = .loading
        defer { progress = nil }

        do {
            progress = "Finding where you start…"
            let start = try await startingPlace(services: services)
            let end = endsAtStart ? start : (endPlace ?? start)

            var errandIDs: [UUID: PersistentIdentifier] = [:]
            let stops = errands.map { errand in
                let stop = errand.makeStop()
                errandIDs[stop.id] = errand.persistentModelID
                return stop
            }

            progress = "Getting walking times…"
            let walkingTimes = try await services.walkingTimes(start.location, end.location, stops)

            progress = "Getting the forecast…"
            let centre = GeoPoint.centroid(of: stops.map(\.location)) ?? start.location
            let forecast = HourlyRainField(samples: try await services.hourlyForecast(centre))

            progress = "Comparing plans…"
            let window = windowStart...windowEnd
            let request = PlanRequest(
                start: start.location,
                end: end.location,
                stops: stops,
                departureWindow: window,
                walkingTimes: walkingTimes,
                timeZone: AppClock.timeZone
            )
            let outcome = await Self.rankSchedules(request, scenarios: ShiftedRainField.scenarios(around: forecast))

            state = .loaded(PlanResult(
                outcome: outcome, start: start, end: end, endsAtStart: endsAtStart,
                window: window, stops: stops, errandIDs: errandIDs
            ))
        } catch is CancellationError {
            state = .idle
        } catch {
            let serviceError = ServiceError(error)
            if serviceError == .locationDenied || serviceError == .locationUnavailable {
                startChoice = .place
            }
            state = .failed(serviceError)
        }
    }

    private func startingPlace(services: PlanServices) async throws -> Place {
        switch startChoice {
        case .currentLocation:
            return Place(name: "Current Location", location: try await services.currentLocation())
        case .place:
            guard let startPlace else { throw ServiceError.other("Choose a start place.") }
            return startPlace
        }
    }

    /// Runs the solver off the main actor: up to 24 orders × 49 departures × 5 scenarios.
    @concurrent
    private static func rankSchedules(_ request: PlanRequest, scenarios: [any RainField]) async -> SolveOutcome {
        ScheduleSolver().rankSchedules(for: request, scenarios: scenarios)
    }

    // MARK: Save

    /// Stores the chosen schedule as a `DayPlan` whose stops copy today's values.
    func save(_ schedule: ScoredSchedule, from result: PlanResult, in context: ModelContext) throws {
        let plan = DayPlan(
            date: schedule.departure,
            start: result.start,
            end: result.endsAtStart ? nil : result.end,
            window: result.window
        )
        plan.departure = schedule.departure
        plan.returnTime = schedule.returnTime
        plan.robustExposure = schedule.robustExposure
        context.insert(plan)

        for (rank, visit) in schedule.visits.enumerated() {
            let errand = result.errandIDs[visit.stop.id].flatMap { context.model(for: $0) as? SavedErrand }
            plan.stops.append(PlannedStop(visit: visit, rank: rank, errand: errand))
        }

        do {
            try context.save()
        } catch {
            Logger.data.error("Plan could not be saved: \(error.localizedDescription, privacy: .public)")
            throw error
        }
    }
}
