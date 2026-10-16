//
//  Ensemble.swift
//  WeatherWindow
//
//  Created by Clement Boudon on 14/10/2026.
//

import Foundation

nonisolated struct Ensemble {
    let times: [Date]
    let members: [[Double]]

    func scenarios(from start: Date, to end: Date) -> [HourlyForecast] {
        var totals: [(member: Int, rain: Double)] = []
        for (member, values) in members.enumerated() {
            var rain = 0.0
            for (hour, time) in times.enumerated() where time > start && time <= end.addingTimeInterval(3600) {
                rain += values[hour]
            }
            totals.append((member, rain))
        }
        totals.sort { $0.rain < $1.rain }

        var forecasts: [HourlyForecast] = []
        for percentile in [0.5, 0.1, 0.3, 0.7, 0.9] {
            let member = totals[Int((Double(totals.count - 1) * percentile).rounded())].member
            var hours: [ForecastHour] = []
            for (hour, time) in times.enumerated() {
                hours.append(ForecastHour(time: time, precipitationProbability: 100, precipitation: members[member][hour]))
            }
            forecasts.append(HourlyForecast(hours: hours))
        }
        return forecasts
    }
}
