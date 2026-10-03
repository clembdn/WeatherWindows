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

@Test func measuresDistanceAcrossTheCBD() {
    let flindersStreet = GeoPoint(latitude: -37.8183, longitude: 144.9671)
    let stateLibrary = GeoPoint(latitude: -37.8098, longitude: 144.9652)

    let metres = flindersStreet.distance(to: stateLibrary)

    #expect(abs(metres - 960) < 20)
    #expect(flindersStreet.distance(to: flindersStreet) == 0)
}

@Test func centroidIsTheAveragePosition() {
    let points = [GeoPoint(latitude: -37.80, longitude: 144.90), GeoPoint(latitude: -37.82, longitude: 145.00)]

    let centre = GeoPoint.centroid(of: points)

    #expect(abs((centre?.latitude ?? 0) + 37.81) < 1e-9)
    #expect(abs((centre?.longitude ?? 0) - 144.95) < 1e-9)
    #expect(GeoPoint.centroid(of: []) == nil)
}

@Test func slicesAThirdOfARoute() throws {
    let line = [GeoPoint(latitude: 0, longitude: 0), GeoPoint(latitude: 0, longitude: 0.03)]

    let middle = RouteGeometry.slice(line, from: 1.0 / 3, to: 2.0 / 3)

    #expect(middle.count == 2)
    #expect(abs(middle[0].longitude - 0.01) < 1e-9)
    #expect(abs(middle[1].longitude - 0.02) < 1e-9)
}

@Test func groupsRainyMinutesIntoSegments() {
    let line = [GeoPoint(latitude: 0, longitude: 0), GeoPoint(latitude: 0, longitude: 0.01),
                GeoPoint(latitude: 0, longitude: 0.04)]

    let segments = RouteGeometry.segments(of: line, rainyMinutes: [false, false, true, true])

    #expect(segments.map(\.isRainy) == [false, true])
    #expect(abs((segments[0].points.last?.longitude ?? 0) - 0.02) < 1e-9)
    #expect(segments[0].points.count == 3)
    #expect(abs((segments[1].points.last?.longitude ?? 0) - 0.04) < 1e-9)
}
