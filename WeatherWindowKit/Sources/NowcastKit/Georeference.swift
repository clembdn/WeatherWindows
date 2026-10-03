import Foundation
import WeatherWindowCore

/// Converts between places and pixels of a radar tile, in spherical Web Mercator like RainViewer and MapKit.
public struct Georeference: Sendable, Hashable {
    public let tile: RadarTile

    public init(tile: RadarTile = .melbourne) {
        self.tile = tile
    }

    /// Width of the whole world in pixels at the tile's zoom.
    private var worldSize: Double {
        Double(tile.size) * pow(2, Double(tile.zoom))
    }

    /// Pixel position inside the tile; values outside 0..<size mean the point is off the tile.
    public func pixel(for point: GeoPoint) -> (x: Double, y: Double) {
        let latitude = point.latitude * .pi / 180
        let worldX = (point.longitude + 180) / 360 * worldSize
        let worldY = (1 - log(tan(latitude) + 1 / cos(latitude)) / .pi) / 2 * worldSize
        return (worldX - Double(tile.x * tile.size), worldY - Double(tile.y * tile.size))
    }

    /// The place at a pixel position (the inverse of `pixel(for:)`).
    public func point(atPixelX x: Double, y: Double) -> GeoPoint {
        let worldX = x + Double(tile.x * tile.size)
        let worldY = y + Double(tile.y * tile.size)
        let longitude = worldX / worldSize * 360 - 180
        let latitude = atan(sinh(.pi * (1 - 2 * worldY / worldSize))) * 180 / .pi
        return GeoPoint(latitude: latitude, longitude: longitude)
    }

    /// Ground size of one pixel at a latitude, in metres (≈ 483 m over Melbourne at zoom 7).
    public func metresPerPixel(atLatitude latitude: Double) -> Double {
        2 * .pi * 6_378_137 * cos(latitude * .pi / 180) / worldSize
    }
}
