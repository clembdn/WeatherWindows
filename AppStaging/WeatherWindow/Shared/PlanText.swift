import Foundation
import SolverKit

/// Wording shared by the plan screens.
nonisolated enum PlanText {
    /// Below this many weighted minutes a walk counts as dry.
    static let dryThreshold = 0.5

    static func isDry(_ exposure: Double) -> Bool {
        exposure < dryThreshold
    }

    /// "Dry" or "Up to ~4 min of rain"; "up to" because the score is the worst scenario.
    static func rain(_ exposure: Double) -> String {
        isDry(exposure) ? "Dry" : "Up to ~\(max(1, Int(exposure.rounded()))) min of rain"
    }

    /// "45 min" or "1 h 05 min".
    static func duration(_ seconds: TimeInterval) -> String {
        let minutes = Int((seconds / 60).rounded())
        guard minutes >= 60 else { return "\(minutes) min" }
        return String(format: "%d h %02d min", minutes / 60, minutes % 60)
    }

    static func reason(_ reason: InfeasibilityReason) -> String {
        switch reason {
        case .closesTooEarly(let name, let closingMinute):
            "\(name) closes at \(AppClock.string(minute: closingMinute)), so it can't fit in this window. "
                + "Try an earlier window or a shorter errand."
        case .missingWalkingTime:
            "A walking time between two of your places is missing. Try again."
        case .noDepartureTimes:
            "The departure window is empty."
        }
    }
}
