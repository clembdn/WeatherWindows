/// The solver's answer: the best trade-offs, or why no plan fits.
public enum SolveOutcome: Sendable {
    /// Schedules that no other one beats on both duration and robust exposure, sorted by duration.
    case frontier([ScoredSchedule])
    case infeasible(InfeasibilityReason)
}

/// Why no schedule could be built, precise enough to show to the user.
public enum InfeasibilityReason: Hashable, Sendable {
    case closesTooEarly(stopName: String, closingMinute: Int)
    case missingWalkingTime(from: Node, to: Node)
    case noDepartureTimes
}
