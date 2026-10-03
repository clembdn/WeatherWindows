import Foundation
import WeatherWindowCore

/// "Leave now" or "wait", for the rest of the day, from where you are now.
public struct DepartureAdvice: Sendable {
    /// The driest plan if you leave right now, if any is feasible.
    public let leaveNow: ScoredSchedule?
    /// A later departure that is clearly drier, when waiting is worth it.
    public let bestLater: ScoredSchedule?
    /// Why nothing fits any more (for example the next place closes too soon).
    public let infeasibility: InfeasibilityReason?

    public var recommendsWaiting: Bool { bestLater != nil }

    public func waitingTime(from now: Date) -> TimeInterval {
        bestLater.map { $0.departure.timeIntervalSince(now) } ?? 0
    }
}

/// Re-plans the remaining errands from the current place over a short window, with the same solver.
public enum DepartureAdvisor {
    /// Waiting must save at least this many weighted minutes of rain to be worth suggesting.
    public static let minimumSaving = 1.0

    /// `request.departureWindow` starts now (usually ending 30 minutes later); closing times still apply.
    public static func advice(for request: PlanRequest, scenarios: [any RainField]) -> DepartureAdvice {
        let now = request.departureWindow.lowerBound
        var immediate = request
        immediate.departureWindow = now...now

        let solver = ScheduleSolver()
        let windowOutcome = solver.rankSchedules(for: request, scenarios: scenarios)
        guard case .frontier(let schedules) = windowOutcome else {
            if case .infeasible(let reason) = windowOutcome {
                return DepartureAdvice(leaveNow: nil, bestLater: nil, infeasibility: reason)
            }
            return DepartureAdvice(leaveNow: nil, bestLater: nil, infeasibility: nil)
        }

        var leaveNow: ScoredSchedule?
        if case .frontier(let immediateSchedules) = solver.rankSchedules(for: immediate, scenarios: scenarios) {
            leaveNow = immediateSchedules.min { $0.robustExposure < $1.robustExposure }
        }

        guard let driest = schedules.last, driest.departure > now else {
            return DepartureAdvice(leaveNow: leaveNow, bestLater: nil, infeasibility: nil)
        }
        let saving = (leaveNow?.robustExposure ?? .infinity) - driest.robustExposure
        return DepartureAdvice(leaveNow: leaveNow, bestLater: saving >= minimumSaving ? driest : nil, infeasibility: nil)
    }
}
