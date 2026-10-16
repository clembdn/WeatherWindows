//
//  RadarForecast.swift
//  WeatherWindow
//
//  Created by Clement Boudon on 7/10/2026.
//

import Foundation

nonisolated struct RadarForecast: RainForecast {
    static let horizon: TimeInterval = 30 * 60

    let frames: [RadarFrame]
    let lastObservation: Date
    let fallback: any RainForecast
    var pixelConverter = PixelConverter()

    func weight(at point: GeoPoint, time: Date) -> Double {
        let forecastWeight = fallback.weight(at: point, time: time)
        let lead = max(0, time.timeIntervalSince(lastObservation))
        let share = max(0, 1 - lead / Self.horizon)
        let closest = frames.min { abs($0.time.timeIntervalSince(time)) < abs($1.time.timeIntervalSince(time)) }
        guard share > 0, let frame = closest else { return forecastWeight }

        let pixel = pixelConverter.pixel(for: point)
        let dBZ = Double(frame.grid.sample(x: pixel.x, y: pixel.y))
        return share * RainRate.weight(dBZ: dBZ) + (1 - share) * forecastWeight
    }
}
