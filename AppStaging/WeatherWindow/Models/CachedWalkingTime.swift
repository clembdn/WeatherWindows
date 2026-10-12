import Foundation
import SwiftData
import WeatherWindowCore

// A walking time from Apple Maps, kept for a week so the same pair of places is asked only once.
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
