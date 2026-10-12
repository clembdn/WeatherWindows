import ForecastKit
import Foundation
import NowcastKit

// The latest RainViewer radar images over Melbourne. It is an actor so decoding the PNGs never blocks the screen.
actor LiveRainViewerSource {
    func frames(upTo time: Date, count: Int) async throws -> [RadarFrame] {
        let (listData, listResponse) = try await URLSession.shared.data(from: RainViewerMaps.endpoint)
        try ServiceError.check(listResponse)
        let maps = try JSONDecoder().decode(RainViewerMaps.self, from: listData)
        let decoder = RadarTileDecoder(palette: try .universalBlue())

        var frames: [RadarFrame] = []
        for frame in maps.radar.past.filter({ $0.time <= time }).suffix(count) {
            guard let url = maps.tileURL(for: frame) else { continue }
            let (png, response) = try await URLSession.shared.data(from: url)
            try ServiceError.check(response)
            frames.append(RadarFrame(grid: try decoder.decode(png).grid, time: frame.time))
        }
        return frames
    }
}
