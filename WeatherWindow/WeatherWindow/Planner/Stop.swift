//
//  Stop.swift
//  WeatherWindow
//
//  Created by Clement Boudon on 7/10/2026.
//

import Foundation

nonisolated enum Waypoint: Hashable {
    case start
    case end
    case stop(UUID)

    func location(start: GeoPoint, end: GeoPoint, stops: [Stop]) -> GeoPoint {
        switch self {
        case .start: start
        case .end: end
        case .stop(let id): stops.first { $0.id == id }?.location ?? start
        }
    }
}

nonisolated struct Stop: Identifiable, Hashable {
    var id = UUID()
    var name: String
    var location: GeoPoint
    var serviceDuration: TimeInterval
    var openingMinute: Int
    var closingMinute: Int
}
