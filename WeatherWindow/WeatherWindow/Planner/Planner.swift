//
//  Planner.swift
//  WeatherWindow
//
//  Created by Clement Boudon on 7/10/2026.
//

import Foundation

nonisolated struct Planner {
    func rankSchedules(for request: PlanRequest, scenarios: [any RainForecast]) -> PlanOutcome {
        let departures = request.departureTimes
        if departures.isEmpty {
            return .noPlan(.noDepartureTimes)
        }
        for pair in PlanRequest.neededPairs(for: request.stops) where request.walkingTimes[pair.from]?[pair.to] == nil {
            return .noPlan(.missingWalkingTime(from: pair.from, to: pair.to))
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = request.timeZone

        var schedules: [Schedule] = []
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
            let blocking = request.stops.max { rejections[$0.id, default: 0] < rejections[$1.id, default: 0] }
            return .noPlan(.closesTooEarly(stopName: blocking?.name ?? "", closingMinute: blocking?.closingMinute ?? 0))
        }
        return .schedules(TradeOffs.best(of: schedules))
    }

    private enum Simulation {
        case scheduled(Schedule)
        case rejected(Stop)
    }

    private func simulate(_ order: [Stop], departingAt departure: Date, request: PlanRequest,
                          calendar: Calendar, scenarios: [any RainForecast]) -> Simulation {
        var time = departure
        var waypoint = Waypoint.start
        var place = request.start
        var visits: [Visit] = []
        var walks: [Walk] = []

        for stop in order {
            let walk = makeWalk(from: waypoint, at: place, to: .stop(stop.id), at: stop.location,
                                departure: time, request: request, scenarios: scenarios)
            walks.append(walk)

            let opening = Self.date(minute: stop.openingMinute, sameDayAs: walk.arrival, calendar: calendar)
            let closing = Self.date(minute: stop.closingMinute, sameDayAs: walk.arrival, calendar: calendar)
            let serviceStart = max(walk.arrival, opening)
            let serviceEnd = serviceStart.addingTimeInterval(stop.serviceDuration)
            if serviceEnd > closing {
                return .rejected(stop)
            }

            visits.append(Visit(stop: stop, arrival: walk.arrival, serviceStart: serviceStart, departure: serviceEnd))
            time = serviceEnd
            waypoint = .stop(stop.id)
            place = stop.location
        }

        let lastWalk = makeWalk(from: waypoint, at: place, to: .end, at: request.end,
                                departure: time, request: request, scenarios: scenarios)
        walks.append(lastWalk)

        var exposures: [Double] = []
        for index in scenarios.indices {
            var total = 0.0
            for walk in walks {
                total += walk.exposureByScenario[index]
            }
            exposures.append(total)
        }

        return .scheduled(Schedule(
            departure: departure,
            returnTime: lastWalk.arrival,
            visits: visits,
            walks: walks,
            exposureByScenario: exposures,
            duration: lastWalk.arrival.timeIntervalSince(request.departureWindow.lowerBound)
        ))
    }

    private func makeWalk(from: Waypoint, at origin: GeoPoint, to: Waypoint, at destination: GeoPoint,
                          departure: Date, request: PlanRequest, scenarios: [any RainForecast]) -> Walk {
        let duration = request.walkingTimes[from]?[to] ?? 0
        let minutes = WalkRain.minutes(from: origin, to: destination, departure: departure, duration: duration)
        var exposures: [Double] = []
        for scenario in scenarios {
            exposures.append(WalkRain.exposure(of: minutes, in: scenario))
        }
        return Walk(from: from, to: to, departure: departure,
                    arrival: departure.addingTimeInterval(duration), exposureByScenario: exposures)
    }

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

    static func date(minute: Int, sameDayAs reference: Date, calendar: Calendar) -> Date {
        let day = calendar.startOfDay(for: reference)
        return calendar.date(bySettingHour: minute / 60, minute: minute % 60, second: 0, of: day) ?? day
    }
}
