//
//  RainViewerService.swift
//  WeatherWindow
//
//  Created by Clement Boudon on 7/10/2026.
//

import Foundation

nonisolated struct RainViewerService {
    static let listURL = URL(string: "https://api.rainviewer.com/public/weather-maps.json")!

    @concurrent
    func frames(upTo time: Date, count: Int) async throws -> [RadarFrame] {
        let (listData, listResponse) = try await URLSession.shared.data(from: Self.listURL)
        try ServiceError.check(listResponse)
        let list = try JSONDecoder().decode(RainViewerResponse.self, from: listData)
        let decoder = RadarTileDecoder(colorTable: try .universalBlue())

        var frames: [RadarFrame] = []
        for frame in list.radar.past.filter({ Date(timeIntervalSince1970: $0.time) <= time }).suffix(count) {
            guard let url = Self.tileURL(host: list.host, path: frame.path) else { continue }
            let (png, response) = try await URLSession.shared.data(from: url)
            try ServiceError.check(response)
            frames.append(RadarFrame(grid: try decoder.decode(png).grid, time: Date(timeIntervalSince1970: frame.time)))
        }
        return frames
    }

    static func tileURL(host: String, path: String, tile: RadarTile = .melbourne) -> URL? {
        guard var components = URLComponents(string: host) else { return nil }
        components.path = path + "/\(tile.size)/\(tile.zoom)/\(tile.x)/\(tile.y)/2/0_0.png"
        return components.url
    }
}

nonisolated struct RainViewerResponse: Decodable {
    let host: String
    let radar: RainViewerRadar
}

nonisolated struct RainViewerRadar: Decodable {
    let past: [RainViewerFrame]
}

nonisolated struct RainViewerFrame: Decodable {
    let time: TimeInterval
    let path: String
}
