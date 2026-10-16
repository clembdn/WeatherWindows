//
//  WalkRain.swift
//  WeatherWindow
//
//  Created by Clement Boudon on 7/10/2026.
//

import Foundation

nonisolated struct WalkMinute: Hashable {
    let point: GeoPoint
    let time: Date
    let minutes: Double
}

nonisolated enum WalkRain {
    static func minutes(from origin: GeoPoint, to destination: GeoPoint,
                        departure: Date, duration: TimeInterval) -> [WalkMinute] {
        guard duration > 0 else { return [] }
        let minuteCount = Int((duration / 60).rounded(.up))

        var minutes: [WalkMinute] = []
        for minute in 0..<minuteCount {
            let start = Double(minute) * 60
            let end = min(start + 60, duration)
            let middle = (start + end) / 2
            let progress = middle / duration
            let point = GeoPoint(
                latitude: origin.latitude + (destination.latitude - origin.latitude) * progress,
                longitude: origin.longitude + (destination.longitude - origin.longitude) * progress
            )
            minutes.append(WalkMinute(point: point, time: departure.addingTimeInterval(middle), minutes: (end - start) / 60))
        }
        return minutes
    }

    static func exposure(of minutes: [WalkMinute], in forecast: any RainForecast) -> Double {
        var total = 0.0
        for minute in minutes {
            total += forecast.weight(at: minute.point, time: minute.time) * minute.minutes
        }
        return total
    }
}
