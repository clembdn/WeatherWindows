//
//  TradeOffs.swift
//  WeatherWindow
//
//  Created by Clement Boudon on 7/10/2026.
//

nonisolated enum TradeOffs {
    static func best(of schedules: [Schedule]) -> [Schedule] {
        let sorted = schedules.sorted { a, b in
            if a.duration != b.duration {
                return a.duration < b.duration
            }
            return a.robustExposure < b.robustExposure
        }

        var kept: [Schedule] = []
        for schedule in sorted {
            if let last = kept.last, schedule.robustExposure >= last.robustExposure - 1e-9 {
                continue
            }
            kept.append(schedule)
        }
        return kept
    }
}
