//
//  NowcastMaker.swift
//  WeatherWindow
//
//  Created by Clement Boudon on 7/10/2026.
//

import Foundation

nonisolated struct Nowcast {
    let observed: [RadarFrame]
    let forecast: [RadarFrame]
    let region: PixelBox
    let rainForecast: RadarForecast

    var lastObservation: Date { rainForecast.lastObservation }
}

nonisolated enum NowcastOutcome {
    case ready(Nowcast)
    case stale(lastObservation: Date)
    case noFrames
    case outsideRadar
}

nonisolated enum NowcastMaker {
    static let maximumAge: TimeInterval = 30 * 60
    static let margin = 73

    static func make(frames: [RadarFrame], around points: [GeoPoint], now: Date,
                     fallback: any RainForecast) -> NowcastOutcome {
        let sorted = frames.sorted { $0.time < $1.time }
        guard let last = sorted.last else { return .noFrames }
        if now.timeIntervalSince(last.time) > maximumAge {
            return .stale(lastObservation: last.time)
        }

        let converter = PixelConverter()
        let size = last.grid.size
        var pixels: [(x: Double, y: Double)] = []
        for point in points {
            let pixel = converter.pixel(for: point)
            if pixel.x < 0 || pixel.y < 0 || pixel.x >= Double(size) || pixel.y >= Double(size) {
                return .outsideRadar
            }
            pixels.append(pixel)
        }

        let region = PixelBox.around(pixels, margin: margin, size: size)
        let motion = MotionFinder().estimate(from: sorted, region: region)
        let forecast = RainMover.forecast(from: last, motion: motion, minutes: 1...30, region: region)
        let rainForecast = RadarForecast(frames: [last] + forecast, lastObservation: last.time, fallback: fallback)
        return .ready(Nowcast(observed: sorted, forecast: forecast, region: region, rainForecast: rainForecast))
    }
}
