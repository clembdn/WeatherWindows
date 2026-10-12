import ForecastKit
import Foundation
import NowcastKit
import SolverKit
import SwiftData
import WeatherWindowCore

// Everything the planner needs from the outside world. The live app, the replay mode and the tests
// each give their own version, so the view models never know where the data comes from.
protocol PlanDataSource {
    var now: Date { get }
    func currentLocation() async throws -> GeoPoint
    func walkingTimes(start: GeoPoint, end: GeoPoint, stops: [Stop]) async throws -> [Node: [Node: TimeInterval]]
    func hourlyForecast(at point: GeoPoint) async throws -> [WeatherSample]
    func radarFrames(upTo time: Date) async throws -> [RadarFrame]
    func routeLine(from origin: GeoPoint, to destination: GeoPoint) async -> [GeoPoint]
}

// Real position, Apple Maps, Open-Meteo and RainViewer.
struct LiveData: PlanDataSource {
    let context: ModelContext
    let location: LocationService
    let paceFactor: Double

    var now: Date { .now }

    func currentLocation() async throws -> GeoPoint {
        try await location.currentLocation()
    }

    func walkingTimes(start: GeoPoint, end: GeoPoint, stops: [Stop]) async throws -> [Node: [Node: TimeInterval]] {
        let directions = DirectionsService(context: context, paceFactor: paceFactor)
        return try await directions.walkingMatrix(start: start, end: end, stops: stops).times
    }

    func hourlyForecast(at point: GeoPoint) async throws -> [WeatherSample] {
        try await OpenMeteoService().hourlyForecast(at: point)
    }

    // Four images give three pairs to measure the motion of the rain.
    func radarFrames(upTo time: Date) async throws -> [RadarFrame] {
        try await LiveRainViewerSource().frames(upTo: time, count: 4)
    }

    func routeLine(from origin: GeoPoint, to destination: GeoPoint) async -> [GeoPoint] {
        await DirectionsService(context: context).routeLine(from: origin, to: destination)
    }
}

// The rainy morning of Saturday 3 October 2026, recorded by `ww record`: works offline, for the demo.
struct ReplayData: PlanDataSource {
    // Five minutes after the 11:00 radar image, because live images also arrive a few minutes late.
    static let now = Date(timeIntervalSince1970: 1_790_989_500)

    var now: Date { Self.now }

    // The app's own files (the staging package used by CI keeps them in its own bundle).
    private var bundle: Bundle {
        #if SWIFT_PACKAGE
        Bundle.module
        #else
        Bundle.main
        #endif
    }

    func currentLocation() async throws -> GeoPoint {
        .melbourneCBD
    }

    // Straight lines at 1.3 m/s (about 4.7 km/h) instead of Apple Maps.
    func walkingTimes(start: GeoPoint, end: GeoPoint, stops: [Stop]) async throws -> [Node: [Node: TimeInterval]] {
        var matrix: [Node: [Node: TimeInterval]] = [:]
        for pair in PlanRequest.neededPairs(for: stops) {
            let from = pair.from.location(start: start, end: end, stops: stops)
            let to = pair.to.location(start: start, end: end, stops: stops)
            matrix[pair.from, default: [:]][pair.to] = from.distance(to: to) / 1.3
        }
        return matrix
    }

    // The Open-Meteo forecast downloaded that morning.
    func hourlyForecast(at point: GeoPoint) async throws -> [WeatherSample] {
        guard let url = bundle.url(forResource: "replay-forecast", withExtension: "json") else {
            throw ServiceError.other("The replay forecast is missing from the app.")
        }
        return try JSONDecoder().decode(OpenMeteoHourlyResponse.self, from: Data(contentsOf: url)).samples
    }

    // Radar tiles from 10:30 to 11:30; only those up to `time` are used.
    func radarFrames(upTo time: Date) async throws -> [RadarFrame] {
        let files = bundle.urls(forResourcesWithExtension: "tile", subdirectory: nil) ?? []
        let source = RecordedFrameSource(files: files, decoder: RadarTileDecoder(palette: try .universalBlue()))
        return try await source.frames(upTo: time, count: 4)
    }

    func routeLine(from origin: GeoPoint, to destination: GeoPoint) async -> [GeoPoint] {
        [origin, destination]
    }
}
