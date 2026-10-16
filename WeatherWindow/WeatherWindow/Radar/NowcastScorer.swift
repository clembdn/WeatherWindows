//
//  NowcastScorer.swift
//  WeatherWindow
//
//  Created by Clement Boudon on 7/10/2026.
//

import Foundation

nonisolated enum NowcastScorer {
    struct Counts: Hashable {
        var hits = 0
        var misses = 0
        var falseAlarms = 0

        var criticalSuccessIndex: Double? {
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

    static func counts(forecast: RainGrid, observed: RainGrid,
                       threshold: Float = RainRate.rainThresholdDBZ,
                       region: PixelBox? = nil) -> Counts {
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

    struct Evaluation: Hashable {
        var nowcast = Counts()
        var persistence = Counts()
        var cases = 0
    }

    static func evaluate(frames: [RadarFrame], leadMinutes: Int, region: PixelBox) -> Evaluation {
        let finder = MotionFinder()
        let sorted = frames.sorted { $0.time < $1.time }
        let history = finder.pairCount + 1
        var evaluation = Evaluation()

        for index in sorted.indices where index + 1 >= history {
            let last = sorted[index]
            let targetTime = last.time.addingTimeInterval(TimeInterval(leadMinutes * 60))
            guard let observed = sorted.first(where: { abs($0.time.timeIntervalSince(targetTime)) < 60 }) else {
                continue
            }

            let recent = Array(sorted[(index + 1 - history)...index])
            let motion = finder.estimate(from: recent, region: region)
            let forecast = RainMover.forecast(from: last, motion: motion, minutes: leadMinutes...leadMinutes, region: region)

            evaluation.nowcast.add(counts(forecast: forecast[0].grid, observed: observed.grid, region: region))
            evaluation.persistence.add(counts(forecast: last.grid, observed: observed.grid, region: region))
            evaluation.cases += 1
        }
        return evaluation
    }
}
