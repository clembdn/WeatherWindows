/// Keeps the schedules that no other schedule beats on both duration and rain.
public enum ParetoFrontier {
    /// The kept schedules, from the fastest to the driest.
    public static func frontier(of schedules: [ScoredSchedule]) -> [ScoredSchedule] {
        let sorted = schedules.sorted { a, b in
            if a.duration != b.duration {
                return a.duration < b.duration
            }
            return a.robustExposure < b.robustExposure
        }

        var kept: [ScoredSchedule] = []
        for schedule in sorted {
            // A slower schedule is only worth showing if it is drier than every faster one.
            if let last = kept.last, schedule.robustExposure >= last.robustExposure - 1e-9 {
                continue
            }
            kept.append(schedule)
        }
        return kept
    }
}
