//
//  HourlyForecast.swift
//  WeatherWindow
//
//  Created by Clement Boudon on 7/10/2026.
//

import Foundation

nonisolated struct HourlyForecast: RainForecast {
    let hours: [ForecastHour]

    init(hours: [ForecastHour]) {
        self.hours = hours.sorted { $0.time < $1.time }
    }

    func weight(at point: GeoPoint, time: Date) -> Double {
        let hour = hours.first { $0.time > time }
        guard let hour, hour.time.timeIntervalSince(time) <= 3600 else { return 0 }
        return hour.rainWeight
    }
}
