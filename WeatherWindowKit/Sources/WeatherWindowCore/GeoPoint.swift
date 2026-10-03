import Foundation

/// A latitude and longitude in degrees, independent of CoreLocation so it builds on Linux.
public struct GeoPoint: Hashable, Sendable, Codable {
    public var latitude: Double
    public var longitude: Double

    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }

    /// Mean Earth radius in metres.
    public static let earthRadius = 6_371_000.0

    /// Great-circle distance in metres (haversine formula).
    public func distance(to other: GeoPoint) -> Double {
        let lat1 = latitude * .pi / 180
        let lat2 = other.latitude * .pi / 180
        let deltaLat = lat2 - lat1
        let deltaLon = (other.longitude - longitude) * .pi / 180
        let a = sin(deltaLat / 2) * sin(deltaLat / 2) + cos(lat1) * cos(lat2) * sin(deltaLon / 2) * sin(deltaLon / 2)
        return 2 * Self.earthRadius * asin(min(1, sqrt(a)))
    }

    /// The average position of some points, used to pick where the hourly forecast is read.
    public static func centroid(of points: [GeoPoint]) -> GeoPoint? {
        guard !points.isEmpty else { return nil }
        let count = Double(points.count)
        return GeoPoint(
            latitude: points.map(\.latitude).reduce(0, +) / count,
            longitude: points.map(\.longitude).reduce(0, +) / count
        )
    }
}
