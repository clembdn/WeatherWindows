import Foundation
import WeatherWindowCore

/// Tries every errand order and departure time, and keeps the best trade-offs between time and rain.
public struct ScheduleSolver: Sendable {
    public init() {}

    /// Ranks every feasible schedule against the rain scenarios; the first scenario is the forecast as is.
    public func rankSchedules(for request: PlanRequest, scenarios: [any RainField]) -> SolveOutcome {
        let departures = request.departureTimes
        guard !departures.isEmpty else { return .infeasible(.noDepartureTimes) }
        if let missing = Self.missingWalkingTime(in: request) {
            return .infeasible(.missingWalkingTime(from: missing.0, to: missing.1))
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = request.timeZone

        var schedules: [ScoredSchedule] = []
        var rejections: [UUID: Int] = [:]
        for order in Self.orders(of: request.stops) {
            for departure in departures {
                switch simulate(order, departingAt: departure, request: request, calendar: calendar, scenarios: scenarios) {
                case .scheduled(let schedule): schedules.append(schedule)
                case .rejected(let stop): rejections[stop.id, default: 0] += 1
                }
            }
        }

        guard !schedules.isEmpty else {
            let blocking = request.stops.max { rejections[$0.id, default: 0] < rejections[$1.id, default: 0] }
            return .infeasible(.closesTooEarly(stopName: blocking?.name ?? "", closingMinute: blocking?.closingMinute ?? 0))
        }
        return .frontier(ParetoFrontier.frontier(of: schedules, first: \.duration, second: \.robustExposure))
    }

    private enum Simulation {
        case scheduled(ScoredSchedule)
        case rejected(Stop)
    }

    /// Walks through the day: wait if a place is still closed, reject if a task would end after closing.
    private func simulate(_ order: [Stop], departingAt departure: Date, request: PlanRequest,
                          calendar: Calendar, scenarios: [any RainField]) -> Simulation {
        var time = departure
        var node = Node.start
        var point = request.start
        var visits: [Visit] = []
        var legs: [Leg] = []

        func walk(to next: Node, at destination: GeoPoint) {
            let duration = request.walkingTimes[node]?[next] ?? 0
            let samples = LegSampler.samples(from: point, to: destination, departure: time, duration: duration)
            let arrival = time.addingTimeInterval(duration)
            legs.append(Leg(
                from: node, to: next, departure: time, arrival: arrival,
                exposureByScenario: scenarios.map { LegSampler.exposure(of: samples, in: $0) }
            ))
            (time, node, point) = (arrival, next, destination)
        }

        for stop in order {
            walk(to: .stop(stop.id), at: stop.location)
            let opening = Self.date(minute: stop.openingMinute, sameDayAs: time, calendar: calendar)
            let closing = Self.date(minute: stop.closingMinute, sameDayAs: time, calendar: calendar)
            let serviceStart = max(time, opening)
            let serviceEnd = serviceStart.addingTimeInterval(stop.serviceDuration)
            guard serviceEnd <= closing else { return .rejected(stop) }

            visits.append(Visit(stop: stop, arrival: time, serviceStart: serviceStart, departure: serviceEnd))
            time = serviceEnd
        }
        walk(to: .end, at: request.end)

        let exposures = scenarios.indices.map { index in legs.reduce(0) { $0 + $1.exposureByScenario[index] } }
        return .scheduled(ScoredSchedule(
            departure: departure,
            returnTime: time,
            visits: visits,
            legs: legs,
            exposureByScenario: exposures,
            duration: time.timeIntervalSince(request.departureWindow.lowerBound)
        ))
    }

    /// Every order in which the stops can be visited (n! of them).
    static func orders<Item>(of items: [Item]) -> [[Item]] {
        guard items.count > 1 else { return [items] }
        return items.indices.flatMap { index in
            var rest = items
            let first = rest.remove(at: index)
            return orders(of: rest).map { [first] + $0 }
        }
    }

    private static func missingWalkingTime(in request: PlanRequest) -> (Node, Node)? {
        let stops = request.stops.map { Node.stop($0.id) }
        let pairs = request.stops.isEmpty
            ? [(Node.start, Node.end)]
            : stops.map { (Node.start, $0) } + stops.map { ($0, Node.end) }
                + stops.flatMap { from in stops.filter { $0 != from }.map { (from, $0) } }
        return pairs.first { request.walkingTimes[$0.0]?[$0.1] == nil }
    }

    /// A clock time given in minutes since midnight, on the same local day as the reference date.
    static func date(minute: Int, sameDayAs reference: Date, calendar: Calendar) -> Date {
        let day = calendar.startOfDay(for: reference)
        let base = calendar.date(byAdding: .day, value: minute / 1440, to: day) ?? day
        let minuteOfDay = minute % 1440
        return calendar.date(bySettingHour: minuteOfDay / 60, minute: minuteOfDay % 60, second: 0, of: base)
            ?? base.addingTimeInterval(TimeInterval(minuteOfDay * 60))
    }
}
