//
//  CachedWalkingTime.swift
//  WeatherWindow
//
//  Created by Clement Boudon on 7/10/2026.
//

import Foundation
import SwiftData

@Model
final class CachedWalkingTime {
    @Attribute(.unique) var key: String
    var seconds: Double
    var createdAt: Date

    init(key: String, seconds: Double) {
        self.key = key
        self.seconds = seconds
        createdAt = .now
    }

    nonisolated static func key(from origin: GeoPoint, to destination: GeoPoint) -> String {
        String(format: "%.5f,%.5f→%.5f,%.5f", origin.latitude, origin.longitude, destination.latitude, destination.longitude)
    }
}
