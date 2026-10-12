import Foundation
import WeatherWindowCore

/// "Leave now" or "wait", for the rest of the day, from where you are now.
public struct DepartureAdvice: Sendable {
    /// The driest plan if you leave right now, if one fits.
    public let leaveNow: ScoredSchedule?
    /// A later departure that is clearly drier, when waiting is worth it.
    public let bestLater: ScoredSchedule?
    /// Why nothing fits any more (for example the next place closes too soon).
    public let infeasibility: InfeasibilityReason?

    /// How long to wait before the later departure, 0 when leaving now.
    public func waitingTime(from now: Date) -> TimeInterval {
        guard let bestLater else { return 0 }
        return bestLater.departure.timeIntervalSince(now)
    }
}

/// Re-plans the remaining errands from the current place over a short window, with the same solver.
public enum DepartureAdvisor {
    /// Waiting must save at least this many minutes of rain to be worth suggesting.
    public static let minimumSaving = 1.0

    /// The request's window starts now (usually 30 minutes long); closing times still apply.
    public static func advice(for request: PlanRequest, scenarios: [any RainField]) -> DepartureAdvice {
        let solver = ScheduleSolver()
        let schedules: [ScoredSchedule]
        switch solver.rankSchedules(for: request, scenarios: scenarios) {
        case .infeasible(let reason):
            return DepartureAdvice(leaveNow: nil, bestLater: nil, infeasibility: reason)
        case .frontier(let frontier):
            schedules = frontier
        }

        let now = request.departureWindow.lowerBound
        var leavingNow = request
        leavingNow.departureWindow = now...now
        var leaveNow: ScoredSchedule?
        if case .frontier(let nowSchedules) = solver.rankSchedules(for: leavingNow, scenarios: scenarios) {
            leaveNow = nowSchedules.min { $0.robustExposure < $1.robustExposure }
        }

        var bestLater: ScoredSchedule?
        if let driest = schedules.last, driest.departure > now {
            let saving = (leaveNow?.robustExposure ?? .infinity) - driest.robustExposure
            if saving >= minimumSaving {
                bestLater = driest
            }
        }
        return DepartureAdvice(leaveNow: leaveNow, bestLater: bestLater, infeasibility: nil)
    }
}
