import Foundation
import Testing
@testable import WeatherWindowCore

@Test func geoPointRoundTripsThroughJSON() throws {
    let cbd = GeoPoint(latitude: -37.8136, longitude: 144.9631)
    let data = try JSONEncoder().encode(cbd)
    #expect(try JSONDecoder().decode(GeoPoint.self, from: data) == cbd)
}

@Test func fixedDateProviderFreezesNow() {
    let recorded = Date(timeIntervalSince1970: 1_790_985_600)
    let provider = FixedDateProvider(now: recorded)
    #expect(provider.now == recorded)
}

@Test func melbourneTimeZoneIsAvailable() throws {
    let melbourne = try #require(TimeZone(identifier: "Australia/Melbourne"))
    let winter = Date(timeIntervalSince1970: 1_782_864_000)
    let summer = Date(timeIntervalSince1970: 1_799_971_200)
    #expect(melbourne.secondsFromGMT(for: winter) == 10 * 3600)
    #expect(melbourne.secondsFromGMT(for: summer) == 11 * 3600)
}
