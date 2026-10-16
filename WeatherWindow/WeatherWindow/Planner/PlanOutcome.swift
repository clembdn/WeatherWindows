//
//  PlanOutcome.swift
//  WeatherWindow
//
//  Created by Clement Boudon on 7/10/2026.
//

nonisolated enum PlanOutcome {
    case schedules([Schedule])
    case noPlan(NoPlanReason)
}

nonisolated enum NoPlanReason: Hashable {
    case closesTooEarly(stopName: String, closingMinute: Int)
    case missingWalkingTime(from: Waypoint, to: Waypoint)
    case noDepartureTimes
}
