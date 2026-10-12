import Foundation
import WeatherWindowCore

/// Tries every errand order and departure time, and keeps the best trade-offs between time and rain.
public struct ScheduleSolver: Sendable {
    public init() {}

    /// Ranks every feasible schedule against the rain scenarios; the first scenario is the forecast as is.
    public func rankSchedules(for request: PlanRequest, scenarios: [any RainField]) -> SolveOutcome {
        let departures = request.departureTimes
        if departures.isEmpty {
            return .infeasible(.noDepartureTimes)
        }
        for pair in PlanRequest.neededPairs(for: request.stops) where request.walkingTimes[pair.from]?[pair.to] == nil {
            return .infeasible(.missingWalkingTime(from: pair.from, to: pair.to))
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = request.timeZone

        var schedules: [ScoredSchedule] = []
        var rejections: [UUID: Int] = [:]
        for order in Self.orders(of: request.stops) {
            for departure in departures {
                let result = simulate(order, departingAt: departure, request: request, calendar: calendar, scenarios: scenarios)
                switch result {
                case .scheduled(let schedule):
                    schedules.append(schedule)
                case .rejected(let stop):
                    rejections[stop.id, default: 0] += 1
                }
            }
        }

        if schedules.isEmpty {
            // The stop that made most schedules fail is the one to tell the user about.
            let blocking = request.stops.max { rejections[$0.id, default: 0] < rejections[$1.id, default: 0] }
            return .infeasible(.closesTooEarly(stopName: blocking?.name ?? "", closingMinute: blocking?.closingMinute ?? 0))
        }
        return .frontier(ParetoFrontier.frontier(of: schedules))
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
        var place = request.start
        var visits: [Visit] = []
        var legs: [Leg] = []

        for stop in order {
            let leg = makeLeg(from: node, at: place, to: .stop(stop.id), at: stop.location,
                              departure: time, request: request, scenarios: scenarios)
            legs.append(leg)

            let opening = Self.date(minute: stop.openingMinute, sameDayAs: leg.arrival, calendar: calendar)
            let closing = Self.date(minute: stop.closingMinute, sameDayAs: leg.arrival, calendar: calendar)
            let serviceStart = max(leg.arrival, opening)
            let serviceEnd = serviceStart.addingTimeInterval(stop.serviceDuration)
            if serviceEnd > closing {
                return .rejected(stop)
            }

            visits.append(Visit(stop: stop, arrival: leg.arrival, serviceStart: serviceStart, departure: serviceEnd))
            time = serviceEnd
            node = .stop(stop.id)
            place = stop.location
        }

        let lastLeg = makeLeg(from: node, at: place, to: .end, at: request.end,
                              departure: time, request: request, scenarios: scenarios)
        legs.append(lastLeg)

        var exposures: [Double] = []
        for index in scenarios.indices {
            var total = 0.0
            for leg in legs {
                total += leg.exposureByScenario[index]
            }
            exposures.append(total)
        }

        return .scheduled(ScoredSchedule(
            departure: departure,
            returnTime: lastLeg.arrival,
            visits: visits,
            legs: legs,
            exposureByScenario: exposures,
            duration: lastLeg.arrival.timeIntervalSince(request.departureWindow.lowerBound)
        ))
    }

    private func makeLeg(from: Node, at origin: GeoPoint, to: Node, at destination: GeoPoint,
                         departure: Date, request: PlanRequest, scenarios: [any RainField]) -> Leg {
        let duration = request.walkingTimes[from]?[to] ?? 0
        let samples = LegSampler.samples(from: origin, to: destination, departure: departure, duration: duration)
        let exposures = scenarios.map { LegSampler.exposure(of: samples, in: $0) }
        return Leg(from: from, to: to, departure: departure,
                   arrival: departure.addingTimeInterval(duration), exposureByScenario: exposures)
    }

    /// Every order in which the stops can be visited (4 stops give 24 orders).
    static func orders(of stops: [Stop]) -> [[Stop]] {
        if stops.count <= 1 {
            return [stops]
        }
        var result: [[Stop]] = []
        for index in stops.indices {
            var rest = stops
            let first = rest.remove(at: index)
            for order in orders(of: rest) {
                result.append([first] + order)
            }
        }
        return result
    }

    /// A clock time given in minutes since midnight, on the same local day as the reference date.
    static func date(minute: Int, sameDayAs reference: Date, calendar: Calendar) -> Date {
        let day = calendar.startOfDay(for: reference)
        return calendar.date(bySettingHour: minute / 60, minute: minute % 60, second: 0, of: day) ?? day
    }
}
