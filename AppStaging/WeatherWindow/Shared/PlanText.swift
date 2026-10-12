import Foundation
import SolverKit

// Sentences shared by the plan screens.
enum PlanText {
    // Less than half a minute of rain counts as a dry walk.
    static func isDry(_ exposure: Double) -> Bool {
        exposure < 0.5
    }

    // "Up to" because the score is the worst of the five scenarios.
    static func rain(_ exposure: Double) -> String {
        if isDry(exposure) {
            return "Dry"
        }
        return "Up to ~\(max(1, Int(exposure.rounded()))) min of rain"
    }

    static func duration(_ seconds: TimeInterval) -> String {
        let minutes = Int((seconds / 60).rounded())
        if minutes < 60 {
            return "\(minutes) min"
        }
        return String(format: "%d h %02d min", minutes / 60, minutes % 60)
    }

    static func reason(_ reason: InfeasibilityReason) -> String {
        switch reason {
        case .closesTooEarly(let name, let closingMinute):
            "\(name) closes at \(Melbourne.time(minute: closingMinute)), so it can't fit in this window. "
                + "Try an earlier window or a shorter errand."
        case .missingWalkingTime:
            "A walking time between two of your places is missing. Try again."
        case .noDepartureTimes:
            "The departure window is empty."
        }
    }
}
