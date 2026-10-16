//
//  RadarTile.swift
//  WeatherWindow
//
//  Created by Clement Boudon on 7/10/2026.
//

nonisolated struct RadarTile: Hashable, Codable {
    var zoom: Int
    var x: Int
    var y: Int
    var size: Int

    static let melbourne = RadarTile(zoom: 7, x: 115, y: 78, size: 512)
}
