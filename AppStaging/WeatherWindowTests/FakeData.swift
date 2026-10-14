import ForecastKit
import Foundation
import NowcastKit
import SolverKit
import WeatherWindowCore
@testable import WeatherWindow

// Ten minutes between any two places, a dry day unless a test gives a forecast, and an error when a test asks for one.
struct FakeData: PlanDataSource {
    var now = Date.now
    var locationError: Error?
    var forecastError: Error?
    var forecast: [WeatherSample] = []
    var ensemble: OpenMeteoEnsembleResponse?
    var frames: [RadarFrame] = []

    func currentLocation() async throws -> GeoPoint {
        if let locationError {
            throw locationError
        }
        return .melbourneCBD
    }

    func walkingTimes(start: GeoPoint, end: GeoPoint, stops: [Stop]) async throws -> [Node: [Node: TimeInterval]] {
        var matrix: [Node: [Node: TimeInterval]] = [:]
        for pair in PlanRequest.neededPairs(for: stops) {
            matrix[pair.from, default: [:]][pair.to] = 10 * 60
        }
        return matrix
    }

    func hourlyForecast(at point: GeoPoint) async throws -> [WeatherSample] {
        if let forecastError {
            throw forecastError
        }
        return forecast
    }

    func ensembleForecast(at point: GeoPoint) async throws -> OpenMeteoEnsembleResponse {
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
