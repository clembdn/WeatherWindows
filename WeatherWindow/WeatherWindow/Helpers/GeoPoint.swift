//
//  GeoPoint.swift
//  WeatherWindow
//
//  Created by Clement Boudon on 7/10/2026.
//

import CoreLocation

nonisolated struct GeoPoint: Hashable, Codable {
    var latitude: Double
    var longitude: Double

    static let melbourneCBD = GeoPoint(latitude: -37.8136, longitude: 144.9631)

    init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }

    init(_ coordinate: CLLocationCoordinate2D) {
        self.init(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    func distance(to other: GeoPoint) -> Double {
        let earthRadius = 6_371_000.0
        let lat1 = latitude * .pi / 180
        let lat2 = other.latitude * .pi / 180
        let deltaLat = lat2 - lat1
        let deltaLon = (other.longitude - longitude) * .pi / 180
        let a = sin(deltaLat / 2) * sin(deltaLat / 2) + cos(lat1) * cos(lat2) * sin(deltaLon / 2) * sin(deltaLon / 2)
        return 2 * earthRadius * asin(min(1, sqrt(a)))
    }

    static func centroid(of points: [GeoPoint]) -> GeoPoint? {
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
