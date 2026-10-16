//
//  DayPlanViewModel.swift
//  WeatherWindow
//
//  Created by Clement Boudon on 7/10/2026.
//

import Foundation
import SwiftData

struct PlanResult {
    let outcome: PlanOutcome
    let start: Place
    let end: Place
    let endsAtStart: Bool
    let errands: [SavedErrand]
    let stops: [Stop]
    let scenarios: [any RainForecast]
    let usesEnsemble: Bool
    let data: any PlanDataSource

    var schedules: [Schedule] {
        if case .schedules(let found) = outcome {
            return found
        }
        return []
    }

    var fastest: Schedule? { schedules.first }
    var driest: Schedule? { schedules.last }

    func name(of waypoint: Waypoint) -> String {
        switch waypoint {
        case .start: start.name
        case .end: end.name
        case .stop(let id): stops.first { $0.id == id }?.name ?? "Errand"
        }
    }

    func location(of waypoint: Waypoint) -> GeoPoint {
        waypoint.location(start: start.location, end: end.location, stops: stops)
    }

    func tradeOff(of schedule: Schedule) -> Double {
        guard schedules.count > 1, let index = schedules.firstIndex(where: { $0.id == schedule.id }) else { return 0.5 }
        return Double(index) / Double(schedules.count - 1)
    }

    func usualChoice(savedTradeOffs: [Double]) -> Schedule? {
        guard savedTradeOffs.count >= 2, !schedules.isEmpty else { return nil }
        var total = 0.0
        for value in savedTradeOffs {
            total += value
        }
        let average = total / Double(savedTradeOffs.count)
        return schedules[Int((average * Double(schedules.count - 1)).rounded())]
    }

    func shareText(for schedule: Schedule) -> String {
        var lines = ["Leave \(start.name) at \(Melbourne.time(schedule.departure))"]
        for (index, visit) in schedule.visits.enumerated() {
            lines.append("\(index + 1). \(visit.stop.name), \(Melbourne.time(visit.serviceStart))–\(Melbourne.time(visit.departure))")
        }
        lines.append("Back at \(end.name) at \(Melbourne.time(schedule.returnTime)) · \(PlanText.rain(schedule.robustExposure))")
        lines.append("Planned with WeatherWindow")
        return lines.joined(separator: "\n")
    }

    func isSaved(_ schedule: Schedule, in context: ModelContext) -> Bool {
        let departure = schedule.departure
        let returnTime = schedule.returnTime
        let sameTimes = FetchDescriptor<DayPlan>(predicate: #Predicate { $0.departure == departure && $0.returnTime == returnTime })
        let plans = (try? context.fetch(sameTimes)) ?? []
        let names = schedule.order.map(\.name)
        return plans.contains { $0.orderedStops.map(\.name) == names }
    }

    func save(_ schedule: Schedule, in context: ModelContext) throws {
        if isSaved(schedule, in: context) {
            return
        }
        let plan = DayPlan(departure: schedule.departure, returnTime: schedule.returnTime,
                           robustExposure: schedule.robustExposure, start: start, end: endsAtStart ? nil : end)
        plan.tradeOff = tradeOff(of: schedule)
        context.insert(plan)
        for (rank, visit) in schedule.visits.enumerated() {
            if let errand = errands.first(where: { $0.id == visit.stop.id }) {
                plan.stops.append(PlannedStop(errand: errand, rank: rank, arrival: visit.arrival, departure: visit.departure))
            }
        }
        try context.save()
    }
}

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
    var usesEnsemble = false

    private(set) var state = LoadState<PlanResult>.idle
    private(set) var progress: String?
    private(set) var selectionMessage: String?

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

    func keepSelected(onlyAmong ids: [UUID]) {
        selectedIDs = selectedIDs.filter { ids.contains($0) }
        if selectedIDs.count < Self.maxErrands {
            selectionMessage = nil
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
            let forecast = HourlyForecast(hours: try await data.hourlyForecast(at: centre))
            var scenarios = ShiftedForecast.scenarios(around: forecast)
            var usedEnsemble = false
            if usesEnsemble {
                progress = "Getting the 40 forecast runs…"
                if let ensemble = try? await data.ensembleForecast(at: centre) {
                    scenarios = ensemble.scenarios(from: windowStart, to: windowEnd.addingTimeInterval(3 * 3600))
                    usedEnsemble = true
                }
            }

            progress = "Comparing plans…"
            let request = PlanRequest(
                start: start.location,
                end: end.location,
                stops: stops,
                departureWindow: windowStart...windowEnd,
                walkingTimes: walkingTimes,
                timeZone: Melbourne.timeZone
            )
            let outcome = await Self.rankSchedules(request, scenarios: scenarios)

            state = .loaded(PlanResult(outcome: outcome, start: start, end: end, endsAtStart: endsAtStart,
                                       errands: errands, stops: stops, scenarios: scenarios, usesEnsemble: usedEnsemble,
                                       data: data))
        } catch {
            let serviceError = ServiceError(error)
            if serviceError == .cancelled {
                state = .idle
                return
            }
            if serviceError.isLocationError {
                startsAtCurrentLocation = false
            }
            state = .failed(serviceError)
        }
    }

    @concurrent
    private static func rankSchedules(_ request: PlanRequest, scenarios: [any RainForecast]) async -> PlanOutcome {
        Planner().rankSchedules(for: request, scenarios: scenarios)
    }
}
