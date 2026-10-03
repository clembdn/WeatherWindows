import Foundation
import SwiftData
import WeatherWindowCore

/// A walking time from Apple Maps, cached per pair of places so adding an errand only asks for the new pairs.
@Model
final class CachedWalkingTime {
    #Unique<CachedWalkingTime>([\.key])

    var key: String
    var seconds: Double
    var createdAt: Date

    init(key: String, seconds: Double, createdAt: Date = .now) {
        self.key = key
        self.seconds = seconds
        self.createdAt = createdAt
    }

    nonisolated static let lifetime: TimeInterval = 7 * 24 * 3600
    /// Bump when the way times are computed changes, so old entries are ignored.
    nonisolated static let schemaVersion = 1

    /// Changes whenever a place, the transport mode or the schema version changes.
    nonisolated static func key(from origin: GeoPoint, to destination: GeoPoint) -> String {
        String(format: "walking|v%d|%.5f,%.5f|%.5f,%.5f", schemaVersion,
               origin.latitude, origin.longitude, destination.latitude, destination.longitude)
    }

    func isFresh(at now: Date) -> Bool {
        now.timeIntervalSince(createdAt) < Self.lifetime
    }
}
