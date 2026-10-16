//
//  FakeData.swift
//  WeatherWindowTests
//
//  Created by Clement Boudon on 12/10/2026.
//

import Foundation
import Testing
@testable import WeatherWindow

struct FakeData: PlanDataSource {
    var now = Date.now
    var locationError: Error?
    var forecastError: Error?
    var forecast: [ForecastHour] = []
    var ensemble: Ensemble?
    var frames: [RadarFrame] = []

    func currentLocation() async throws -> GeoPoint {
        if let locationError {
            throw locationError
        }
        return .melbourneCBD
    }

    func walkingTimes(start: GeoPoint, end: GeoPoint, stops: [Stop]) async throws -> [Waypoint: [Waypoint: TimeInterval]] {
        var matrix: [Waypoint: [Waypoint: TimeInterval]] = [:]
        for pair in PlanRequest.neededPairs(for: stops) {
            matrix[pair.from, default: [:]][pair.to] = 10 * 60
        }
        return matrix
    }

    func hourlyForecast(at point: GeoPoint) async throws -> [ForecastHour] {
        if let forecastError {
            throw forecastError
        }
        return forecast
    }

    func ensembleForecast(at point: GeoPoint) async throws -> Ensemble {
        guard let ensemble else { throw ServiceError.offline }
        return ensemble
    }

    func radarFrames(upTo time: Date) async throws -> [RadarFrame] {
        frames
    }

    func routeLine(from origin: GeoPoint, to destination: GeoPoint) async -> [GeoPoint] {
        [origin, destination]
    }
}

final class TestFiles {}

func fixture(_ name: String) throws -> Data {
    let url = try #require(Bundle(for: TestFiles.self).url(forResource: name, withExtension: "json"))
    return try Data(contentsOf: url)
}
