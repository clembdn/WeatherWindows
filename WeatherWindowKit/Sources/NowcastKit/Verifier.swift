import Foundation

/// Scores a rain forecast against what the radar later observed.
public enum Verifier {
    public struct Counts: Hashable, Sendable {
        public var hits = 0
        public var misses = 0
        public var falseAlarms = 0

        /// Critical Success Index = hits / (hits + misses + false alarms); nil when neither grid has rain.
        public var criticalSuccessIndex: Double? {
            let total = hits + misses + falseAlarms
            return total == 0 ? nil : Double(hits) / Double(total)
        }
    }

    /// Compares rain (≥ threshold) pixel by pixel inside the region.
    public static func counts(forecast: RainGrid, observed: RainGrid, threshold: Float = 20,
                              region: PixelRegion? = nil) -> Counts {
        let area = region ?? .whole(size: observed.size)
        var counts = Counts()
        for y in area.minY...area.maxY {
            for x in area.minX...area.maxX {
                let predicted = forecast[x, y] >= threshold
                let happened = observed[x, y] >= threshold
                switch (predicted, happened) {
                case (true, true): counts.hits += 1
                case (false, true): counts.misses += 1
                case (true, false): counts.falseAlarms += 1
                case (false, false): break
                }
            }
        }
        return counts
    }

    /// Nowcast and persistence ("the rain does not move") scored on the same cases.
    public struct Evaluation: Hashable, Sendable {
        public var nowcast = Counts()
        public var persistence = Counts()
        public var cases = 0
    }

    /// Replays recorded frames: from every frame with three earlier pairs, forecast `leadMinutes` ahead
    /// and compare with the frame actually observed then.
    public static func evaluate(frames: [RadarFrame], leadMinutes: Int, region: PixelRegion,
                                estimator: BlockMatchingEstimator = BlockMatchingEstimator(),
                                threshold: Float = 20) -> Evaluation {
        let sorted = frames.sorted { $0.time < $1.time }
        let history = estimator.pairCount + 1
        var evaluation = Evaluation()

        for index in sorted.indices where index + 1 >= history {
            let last = sorted[index]
            let targetTime = last.time.addingTimeInterval(TimeInterval(leadMinutes * 60))
            guard let observed = sorted.first(where: { abs($0.time.timeIntervalSince(targetTime)) < 60 }) else { continue }

            let recent = Array(sorted[(index + 1 - history)...index])
            let motion = estimator.estimate(from: recent, region: region)
            guard let forecast = Advector.forecast(from: last, motion: motion,
                                                   minutes: leadMinutes...leadMinutes, region: region).first else { continue }

            let nowcast = counts(forecast: forecast.grid, observed: observed.grid, threshold: threshold, region: region)
            let persistence = counts(forecast: last.grid, observed: observed.grid, threshold: threshold, region: region)
            evaluation.nowcast.hits += nowcast.hits
            evaluation.nowcast.misses += nowcast.misses
            evaluation.nowcast.falseAlarms += nowcast.falseAlarms
            evaluation.persistence.hits += persistence.hits
            evaluation.persistence.misses += persistence.misses
            evaluation.persistence.falseAlarms += persistence.falseAlarms
            evaluation.cases += 1
        }
        return evaluation
    }
}
