//
//  Schedule.swift
//  WeatherWindow
//
//  Created by Clement Boudon on 7/10/2026.
//

import Foundation

nonisolated struct Visit: Hashable {
    let stop: Stop
    let arrival: Date
    let serviceStart: Date
    let departure: Date

    var waiting: TimeInterval { serviceStart.timeIntervalSince(arrival) }
}

nonisolated struct Walk: Hashable {
    let from: Waypoint
    let to: Waypoint
    let departure: Date
    let arrival: Date
    let exposureByScenario: [Double]
}

nonisolated struct Schedule: Hashable, Identifiable {
    let departure: Date
    let returnTime: Date
    let visits: [Visit]
    let walks: [Walk]
    let exposureByScenario: [Double]
    let duration: TimeInterval

    var robustExposure: Double { exposureByScenario.max() ?? 0 }

    var confidence: Int {
        let spread = (exposureByScenario.max() ?? 0) - (exposureByScenario.min() ?? 0)
        if spread < 2 {
            return 3
        }
        if spread < 5 {
            return 2
        }
        return 1
    }

    var order: [Stop] { visits.map(\.stop) }

    var id: String {
        "\(departure.timeIntervalSince1970)-" + order.map(\.id.uuidString).joined(separator: ",")
    }
}
