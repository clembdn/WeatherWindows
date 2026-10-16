//
//  ForecastTests.swift
//  WeatherWindowTests
//
//  Created by Clement Boudon on 7/10/2026.
//

import Foundation
import Testing
@testable import WeatherWindow

@Test func decodesHourlyFixture() throws {
    let url = try #require(Bundle.main.url(forResource: "replay-forecast", withExtension: "json"))

    let hours = try OpenMeteoService.forecastHours(from: Data(contentsOf: url))

    #expect(hours.count == 48)
    #expect(hours.first?.time == Date(timeIntervalSince1970: 1_790_985_600))
    #expect(hours.first?.precipitationProbability == 100)
    #expect(hours.first?.precipitation == 0.7)
}

@Test func toleratesNullValues() throws {
    let json = """
        {"latitude": -37.8, "longitude": 144.9, "hourly": {
            "time": [1790985600, 1790989200],
            "precipitation_probability": [null, 40],
            "precipitation": [1.5, null]
        }}
        """

    let hours = try OpenMeteoService.forecastHours(from: Data(json.utf8))

    #expect(hours.map(\.precipitationProbability) == [0, 40])
    #expect(hours.map(\.precipitation) == [1.5, 0])
}

@Test func rejectsMismatchedArrays() {
    let json = """
        {"latitude": -37.8, "longitude": 144.9, "hourly": {
            "time": [1790985600, 1790989200],
            "precipitation_probability": [10],
            "precipitation": [0.0, 0.2]
        }}
        """

    #expect(throws: ServiceError.invalidResponse) {
        try OpenMeteoService.forecastHours(from: Data(json.utf8))
    }
}

@Test(arguments: [
    (60.0, 0.5, 0.3),
    (100.0, 3.0, 1.0),
    (0.0, 2.0, 0.0)
])
func rainWeightExamples(probability: Double, precipitation: Double, expected: Double) {
    let hour = ForecastHour(time: .now, precipitationProbability: probability, precipitation: precipitation)
    #expect(abs(hour.rainWeight - expected) < 1e-9)
}

@Test func decodesEnsembleFixture() throws {
    let ensemble = try OpenMeteoService.ensemble(from: fixture("ensemble_melbourne"))

    #expect(ensemble.times.count == 48)
    #expect(ensemble.times.first == Date(timeIntervalSince1970: 1_791_763_200))
    #expect(ensemble.members.count == 40)
    #expect(ensemble.members.allSatisfy { $0.count == 48 })
}

@Test func picksFiveRunsFromDryToWet() throws {
    let json = """
        {"hourly": {
            "time": [1790989200, 1790992800],
            "precipitation": [0.5, 0.5],
            "precipitation_member01": [0, 0],
            "precipitation_member02": [3, 3],
            "precipitation_member03": [0.2, 0.2],
            "precipitation_member04": [1, 1]
        }}
        """
    let ensemble = try OpenMeteoService.ensemble(from: Data(json.utf8))
    let start = Date(timeIntervalSince1970: 1_790_985_600)

    let scenarios = ensemble.scenarios(from: start, to: start.addingTimeInterval(2 * 3600))

    let weights = scenarios.map { $0.weight(at: GeoPoint(latitude: -37.81, longitude: 144.96), time: start.addingTimeInterval(1800)) }
    #expect(weights == [0.5, 0, 0.2, 1, 1])
}

@Test func rejectsAnEnsembleWithoutRain() {
    let json = """
        {"hourly": {"time": [1790989200]}}
        """

    #expect(throws: ServiceError.invalidResponse) {
        try OpenMeteoService.ensemble(from: Data(json.utf8))
    }
}

@Test func buildsEnsembleURL() throws {
    let url = try #require(OpenMeteoService.ensembleURL(at: GeoPoint(latitude: -37.8136, longitude: 144.9631)))
    let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))

    #expect(components.host == "ensemble-api.open-meteo.com")
    #expect(components.queryItems?.contains(URLQueryItem(name: "models", value: "icon_seamless")) == true)
    #expect(components.queryItems?.contains(URLQueryItem(name: "timeformat", value: "unixtime")) == true)
}
