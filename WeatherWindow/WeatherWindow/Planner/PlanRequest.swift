//
//  PlanRequest.swift
//  WeatherWindow
//
//  Created by Clement Boudon on 7/10/2026.
//

import Foundation

nonisolated struct PlanRequest {
    var start: GeoPoint
    var end: GeoPoint
    var stops: [Stop]
    var departureWindow: ClosedRange<Date>
    var departureStep: TimeInterval = 5 * 60
    var walkingTimes: [Waypoint: [Waypoint: TimeInterval]]
    var timeZone: TimeZone

    var departureTimes: [Date] {
        guard departureStep > 0 else { return [] }
        var times: [Date] = []
        var time = departureWindow.lowerBound
        while time <= departureWindow.upperBound {
            times.append(time)
            time.addTimeInterval(departureStep)
        }
        return times
    }

    static func neededPairs(for stops: [Stop]) -> [(from: Waypoint, to: Waypoint)] {
        if stops.isEmpty {
            return [(.start, .end)]
        }
        var pairs: [(from: Waypoint, to: Waypoint)] = []
        for stop in stops {
            pairs.append((.start, .stop(stop.id)))
            pairs.append((.stop(stop.id), .end))
        }
        for from in stops {
            for to in stops where to.id != from.id {
                pairs.append((.stop(from.id), .stop(to.id)))
            }
        }
        return pairs
    }
}
