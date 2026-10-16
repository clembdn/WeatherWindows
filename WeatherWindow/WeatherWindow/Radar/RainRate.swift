//
//  RainRate.swift
//  WeatherWindow
//
//  Created by Clement Boudon on 7/10/2026.
//

import Foundation

nonisolated enum RainRate {
    static let rainThresholdDBZ: Float = 20

    static func mmPerHour(dBZ: Double) -> Double {
        let z = pow(10, dBZ / 10)
        return pow(z / 200, 1 / 1.6)
    }

    static func weight(dBZ: Double) -> Double {
        guard dBZ > Double(RadarColorTable.noEchoDBZ) else { return 0 }
        return min(1, mmPerHour(dBZ: dBZ))
    }
}
