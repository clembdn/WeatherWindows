import Foundation
import Testing
@testable import ForecastKit

@Test func decodesWeatherMapsFixture() throws {
    let maps = try loadMaps()

    #expect(maps.host == "https://tilecache.rainviewer.com")
    #expect(maps.radar.past.count == 13)
    #expect(maps.radar.past.first?.time == Date(timeIntervalSince1970: 1_790_984_400))
}

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
