//
//  DepartureAdvisor.swift
//  WeatherWindow
//
//  Created by Clement Boudon on 7/10/2026.
//

import Foundation

nonisolated struct DepartureAdvice {
    let leaveNow: Schedule?
    let bestLater: Schedule?
    let noPlanReason: NoPlanReason?

    func waitingTime(from now: Date) -> TimeInterval {
        guard let bestLater else { return 0 }
        return bestLater.departure.timeIntervalSince(now)
    }
}

nonisolated enum DepartureAdvisor {
    static let minimumSaving = 1.0

    static func advice(for request: PlanRequest, scenarios: [any RainForecast]) -> DepartureAdvice {
        let planner = Planner()
        let schedules: [Schedule]
        switch planner.rankSchedules(for: request, scenarios: scenarios) {
        case .noPlan(let reason):
            return DepartureAdvice(leaveNow: nil, bestLater: nil, noPlanReason: reason)
        case .schedules(let found):
            schedules = found
        }

        let now = request.departureWindow.lowerBound
        var leavingNow = request
        leavingNow.departureWindow = now...now
        var leaveNow: Schedule?
        if case .schedules(let nowSchedules) = planner.rankSchedules(for: leavingNow, scenarios: scenarios) {
            leaveNow = nowSchedules.min { $0.robustExposure < $1.robustExposure }
        }

        var bestLater: Schedule?
        if let driest = schedules.last, driest.departure > now {
            let saving = (leaveNow?.robustExposure ?? .infinity) - driest.robustExposure
            if saving >= minimumSaving {
                bestLater = driest
            }
        }
        return DepartureAdvice(leaveNow: leaveNow, bestLater: bestLater, noPlanReason: nil)
    }
}
