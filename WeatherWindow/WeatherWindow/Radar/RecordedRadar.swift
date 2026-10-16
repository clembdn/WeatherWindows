//
//  RecordedRadar.swift
//  WeatherWindow
//
//  Created by Clement Boudon on 7/10/2026.
//

import Foundation

nonisolated struct RecordedRadar {
    let files: [URL]
    let decoder: RadarTileDecoder

    init(files: [URL], decoder: RadarTileDecoder) {
        self.files = files.filter { $0.pathExtension == "png" || $0.pathExtension == "tile" }
        self.decoder = decoder
    }

    @concurrent
    func frames(upTo time: Date, count: Int) async throws -> [RadarFrame] {
        var chosen: [(file: URL, time: Date)] = []
        for file in files {
            if let captured = Self.captureTime(of: file), captured <= time {
                chosen.append((file, captured))
            }
        }
        chosen.sort { $0.time < $1.time }

        var frames: [RadarFrame] = []
        for item in chosen.suffix(count) {
            let grid = try decoder.decode(Data(contentsOf: item.file)).grid
            frames.append(RadarFrame(grid: grid, time: item.time))
        }
        return frames
    }

    private static func captureTime(of file: URL) -> Date? {
        let digits = file.deletingPathExtension().lastPathComponent.filter(\.isNumber)
        guard let seconds = TimeInterval(digits) else { return nil }
        return Date(timeIntervalSince1970: seconds)
    }
}
