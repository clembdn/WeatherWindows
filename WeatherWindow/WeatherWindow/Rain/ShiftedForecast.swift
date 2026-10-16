//
//  ShiftedForecast.swift
//  WeatherWindow
//
//  Created by Clement Boudon on 7/10/2026.
//

import Foundation

nonisolated struct ShiftedForecast: RainForecast {
    let base: any RainForecast
    let offset: TimeInterval

    func weight(at point: GeoPoint, time: Date) -> Double {
        base.weight(at: point, time: time.addingTimeInterval(-offset))
    }

    static func scenarios(around base: any RainForecast) -> [any RainForecast] {
        [
            base,
            ShiftedForecast(base: base, offset: -30 * 60),
            ShiftedForecast(base: base, offset: -15 * 60),
            ShiftedForecast(base: base, offset: 15 * 60),
            ShiftedForecast(base: base, offset: 30 * 60)
        ]
    }
}
