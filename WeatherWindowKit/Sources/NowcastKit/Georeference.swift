import Foundation
import WeatherWindowCore

/// Converts places into pixels of a radar tile, in spherical Web Mercator like RainViewer and MapKit.
public struct Georeference: Sendable, Hashable {
    public let tile: RadarTile

    public init(tile: RadarTile = .melbourne) {
        self.tile = tile
    }

    /// Pixel position inside the tile; values outside 0..<size mean the point is off the tile.
    public func pixel(for point: GeoPoint) -> (x: Double, y: Double) {
        let worldSize = Double(tile.size) * pow(2, Double(tile.zoom))
        let latitude = point.latitude * .pi / 180
        let worldX = (point.longitude + 180) / 360 * worldSize
        let worldY = (1 - log(tan(latitude) + 1 / cos(latitude)) / .pi) / 2 * worldSize
        return (worldX - Double(tile.x * tile.size), worldY - Double(tile.y * tile.size))
    }
}
