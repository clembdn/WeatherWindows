import Foundation

/// A latitude and longitude in degrees, independent of CoreLocation so it builds on Linux.
public struct GeoPoint: Hashable, Sendable, Codable {
    public var latitude: Double
    public var longitude: Double

    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }

    /// Distance in metres along the Earth's surface (haversine formula).
    public func distance(to other: GeoPoint) -> Double {
        let earthRadius = 6_371_000.0
        let lat1 = latitude * .pi / 180
        let lat2 = other.latitude * .pi / 180
        let deltaLat = lat2 - lat1
        let deltaLon = (other.longitude - longitude) * .pi / 180
        let a = sin(deltaLat / 2) * sin(deltaLat / 2) + cos(lat1) * cos(lat2) * sin(deltaLon / 2) * sin(deltaLon / 2)
        return 2 * earthRadius * asin(min(1, sqrt(a)))
    }

    /// The average position of some points, where the hourly forecast is read.
    public static func centroid(of points: [GeoPoint]) -> GeoPoint? {
        if points.isEmpty { return nil }
        var latitude = 0.0
        var longitude = 0.0
        for point in points {
            latitude += point.latitude
            longitude += point.longitude
        }
        return GeoPoint(latitude: latitude / Double(points.count), longitude: longitude / Double(points.count))
    }
}
