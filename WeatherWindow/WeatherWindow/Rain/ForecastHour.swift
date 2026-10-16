//
//  ForecastHour.swift
//  WeatherWindow
//
//  Created by Clement Boudon on 7/10/2026.
//

import Foundation

nonisolated struct ForecastHour: Hashable {
    let time: Date
    let precipitationProbability: Double
    let precipitation: Double

    var rainWeight: Double {
        let chance = min(max(precipitationProbability / 100, 0), 1)
        let intensity = min(max(precipitation, 0), 1)
        return chance * intensity
    }
}
