//
//  RainForecast.swift
//  WeatherWindow
//
//  Created by Clement Boudon on 7/10/2026.
//

import Foundation

nonisolated protocol RainForecast: Sendable {
    func weight(at point: GeoPoint, time: Date) -> Double
}
