import Foundation

/// Scores a rain forecast against what the radar later observed.
public enum Verifier {
    /// Pixels where rain was forecast and observed (hits), observed only (misses) or forecast only (false alarms).
    public struct Counts: Hashable, Sendable {
        public var hits = 0
        public var misses = 0
        public var falseAlarms = 0

        /// Critical Success Index = hits / (hits + misses + false alarms); nil when neither grid has rain.
        public var criticalSuccessIndex: Double? {
            let total = hits + misses + falseAlarms
            if total == 0 { return nil }
            return Double(hits) / Double(total)
        }

        mutating func add(_ other: Counts) {
            hits += other.hits
            misses += other.misses
            falseAlarms += other.falseAlarms
        }
    }

    /// Compares rain (at or above the threshold) pixel by pixel inside the region.
    public static func counts(forecast: RainGrid, observed: RainGrid,
                              threshold: Float = ReflectivityConverter.rainThresholdDBZ,
                              region: PixelRegion? = nil) -> Counts {
        let area = region ?? .whole(size: observed.size)
        var counts = Counts()
        for y in area.minY...area.maxY {
            for x in area.minX...area.maxX {
                let predicted = forecast[x, y] >= threshold
                let happened = observed[x, y] >= threshold
                if predicted && happened {
                    counts.hits += 1
                } else if happened {
                    counts.misses += 1
                } else if predicted {
                    counts.falseAlarms += 1
                }
            }
        }
        return counts
    }

    /// The nowcast and persistence ("the rain does not move") scored on the same cases.
    public struct Evaluation: Hashable, Sendable {
        public var nowcast = Counts()
        public var persistence = Counts()
        public var cases = 0
    }

    /// Replays recorded frames: from every frame with three earlier pairs, forecast `leadMinutes` ahead
    /// and compare with the frame actually observed then.
    public static func evaluate(frames: [RadarFrame], leadMinutes: Int, region: PixelRegion) -> Evaluation {
        let estimator = BlockMatchingEstimator()
        let sorted = frames.sorted { $0.time < $1.time }
        let history = estimator.pairCount + 1
        var evaluation = Evaluation()

        for index in sorted.indices where index + 1 >= history {
            let last = sorted[index]
            let targetTime = last.time.addingTimeInterval(TimeInterval(leadMinutes * 60))
            guard let observed = sorted.first(where: { abs($0.time.timeIntervalSince(targetTime)) < 60 }) else {
                continue
            }

            let recent = Array(sorted[(index + 1 - history)...index])
            let motion = estimator.estimate(from: recent, region: region)
            let forecast = Advector.forecast(from: last, motion: motion, minutes: leadMinutes...leadMinutes, region: region)

            evaluation.nowcast.add(counts(forecast: forecast[0].grid, observed: observed.grid, region: region))
            evaluation.persistence.add(counts(forecast: last.grid, observed: observed.grid, region: region))
            evaluation.cases += 1
        }
        return evaluation
    }
}
