//
//  PixelConverter.swift
//  WeatherWindow
//
//  Created by Clement Boudon on 7/10/2026.
//

import Foundation

nonisolated struct PixelConverter: Hashable {
    var tile: RadarTile = .melbourne

    func pixel(for point: GeoPoint) -> (x: Double, y: Double) {
        let worldSize = Double(tile.size) * pow(2, Double(tile.zoom))
        let latitude = point.latitude * .pi / 180
        let worldX = (point.longitude + 180) / 360 * worldSize
        let worldY = (1 - log(tan(latitude) + 1 / cos(latitude)) / .pi) / 2 * worldSize
        return (worldX - Double(tile.x * tile.size), worldY - Double(tile.y * tile.size))
    }

    func point(forPixelX x: Double, y: Double) -> GeoPoint {
        let worldSize = Double(tile.size) * pow(2, Double(tile.zoom))
        let worldX = x + Double(tile.x * tile.size)
        let worldY = y + Double(tile.y * tile.size)
        let longitude = worldX / worldSize * 360 - 180
        let latitude = atan(sinh(.pi * (1 - 2 * worldY / worldSize))) * 180 / .pi
        return GeoPoint(latitude: latitude, longitude: longitude)
    }
}
