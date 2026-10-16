//
//  NextWalkTests.swift
//  WeatherWindowTests
//
//  Created by Clement Boudon on 7/10/2026.
//

import Foundation
import Testing
@testable import WeatherWindow

struct NextWalkTests {
    @Test func advisesFromTheRecordedRadar() async throws {
        let model = NextWalkViewModel(input: NextWalkInput(
            current: Place(name: "Melbourne Central", location: GeoPoint(latitude: -37.8102, longitude: 144.9628)),
            remaining: [Stop(name: "Library", location: GeoPoint(latitude: -37.8098, longitude: 144.9652),
                             serviceDuration: 20 * 60, openingMinute: 9 * 60, closingMinute: 18 * 60)],
            end: Place(name: "Flinders Street", location: GeoPoint(latitude: -37.8183, longitude: 144.9671))
        ))

        await model.load(data: ReplayData())

        guard case .loaded(let result) = model.state else {
            Issue.record("Expected advice, got \(model.state)")
            return
        }
        #expect(result.nowcast != nil)
        #expect(result.radarNotice == nil)
        #expect(result.recommended != nil)
        #expect(result.now == ReplayData.now)
    }

    @Test func fallsBackToTheForecastWhenRadarIsStale() async throws {
        var data = FakeData()
        data.now = ReplayData.now.addingTimeInterval(45 * 60)
        data.frames = try await ReplayData().radarFrames(upTo: ReplayData.now)
        let model = NextWalkViewModel(input: NextWalkInput(
            current: Place(name: "CBD", location: .melbourneCBD),
            remaining: [],
            end: Place(name: "Home", location: GeoPoint(latitude: -37.8183, longitude: 144.9671))
        ))

        await model.load(data: data)

        guard case .loaded(let result) = model.state else {
            Issue.record("Expected advice, got \(model.state)")
            return
        }
        #expect(result.nowcast == nil)
        #expect(result.radarNotice?.contains("too old") == true)
    }

    @Test func alertsOnceWhenRainHeadsForTheNextWalk() async {
        var data = FakeData()
        data.now = ReplayData.now
        data.forecast = [ForecastHour(time: data.now.addingTimeInterval(1800), precipitationProbability: 100, precipitation: 3),
                         ForecastHour(time: data.now.addingTimeInterval(5400), precipitationProbability: 100, precipitation: 3)]
        let model = NextWalkViewModel(input: NextWalkInput(
            current: Place(name: "CBD", location: .melbourneCBD),
            remaining: [],
            end: Place(name: "Home", location: GeoPoint(latitude: -37.8183, longitude: 144.9671))
        ))
        await model.load(data: data)

        #expect(model.rainAlert() == nil)
        model.alertsWhenRainComes = true
        #expect(model.rainAlert()?.hasPrefix("Rain is expected on your walk to Home") == true)
        await model.load(data: data)
        #expect(model.rainAlert() == nil)
    }
}
