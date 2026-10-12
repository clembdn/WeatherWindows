import Foundation
import Testing
@testable import ForecastKit

@Test func buildsTileURL() throws {
    let maps = try loadMaps()
    let frame = try #require(maps.radar.past.first)

    let url = maps.tileURL(for: frame)

    #expect(url?.absoluteString == "https://tilecache.rainviewer.com/v2/radar/d39cd0573090/512/7/115/78/2/0_0.png")
}

private func loadMaps() throws -> RainViewerMaps {
    let url = try #require(Bundle.module.url(forResource: "weather_maps", withExtension: "json", subdirectory: "Fixtures"))
    return try JSONDecoder().decode(RainViewerMaps.self, from: Data(contentsOf: url))
}
