//
//  PlanDataSource.swift
//  WeatherWindow
//
//  Created by Clement Boudon on 12/10/2026.
//

import Foundation
import SwiftData

protocol PlanDataSource {
    var now: Date { get }
    func currentLocation() async throws -> GeoPoint
    func walkingTimes(start: GeoPoint, end: GeoPoint, stops: [Stop]) async throws -> [Waypoint: [Waypoint: TimeInterval]]
    func hourlyForecast(at point: GeoPoint) async throws -> [ForecastHour]
    func ensembleForecast(at point: GeoPoint) async throws -> Ensemble
    func radarFrames(upTo time: Date) async throws -> [RadarFrame]
    func routeLine(from origin: GeoPoint, to destination: GeoPoint) async -> [GeoPoint]
}

struct LiveData: PlanDataSource {
    let context: ModelContext
    let location: LocationService
    let paceFactor: Double

    var now: Date { .now }

    func currentLocation() async throws -> GeoPoint {
        try await location.currentLocation()
    }

    func walkingTimes(start: GeoPoint, end: GeoPoint, stops: [Stop]) async throws -> [Waypoint: [Waypoint: TimeInterval]] {
        let directions = DirectionsService(context: context, paceFactor: paceFactor)
        return try await directions.walkingMatrix(start: start, end: end, stops: stops).times
    }

    func hourlyForecast(at point: GeoPoint) async throws -> [ForecastHour] {
        try await OpenMeteoService().hourlyForecast(at: point)
    }

    func ensembleForecast(at point: GeoPoint) async throws -> Ensemble {
        try await OpenMeteoService().ensemble(at: point)
    }

    func radarFrames(upTo time: Date) async throws -> [RadarFrame] {
        try await RainViewerService().frames(upTo: time, count: 4)
    }

    func routeLine(from origin: GeoPoint, to destination: GeoPoint) async -> [GeoPoint] {
        await DirectionsService.routeLine(from: origin, to: destination)
    }
}

struct ReplayData: PlanDataSource {
    static let now = Date(timeIntervalSince1970: 1_790_989_500)

    var now: Date { Self.now }

    func currentLocation() async throws -> GeoPoint {
        .melbourneCBD
    }

    func walkingTimes(start: GeoPoint, end: GeoPoint, stops: [Stop]) async throws -> [Waypoint: [Waypoint: TimeInterval]] {
        var matrix: [Waypoint: [Waypoint: TimeInterval]] = [:]
        for pair in PlanRequest.neededPairs(for: stops) {
            let from = pair.from.location(start: start, end: end, stops: stops)
            let to = pair.to.location(start: start, end: end, stops: stops)
            matrix[pair.from, default: [:]][pair.to] = from.distance(to: to) / 1.3
        }
        return matrix
    }

    func hourlyForecast(at point: GeoPoint) async throws -> [ForecastHour] {
        guard let url = Bundle.main.url(forResource: "replay-forecast", withExtension: "json") else {
            throw ServiceError.other("The replay forecast is missing from the app.")
        }
        return try OpenMeteoService.forecastHours(from: Data(contentsOf: url))
    }

    func ensembleForecast(at point: GeoPoint) async throws -> Ensemble {
        throw ServiceError.other("No ensemble forecast was recorded for the replay.")
    }

    func radarFrames(upTo time: Date) async throws -> [RadarFrame] {
        try await recordedRadar().frames(upTo: time, count: 4)
    }

    func allRadarFrames() async throws -> [RadarFrame] {
        try await recordedRadar().frames(upTo: .distantFuture, count: 200)
    }

    private func recordedRadar() throws -> RecordedRadar {
        let files = Bundle.main.urls(forResourcesWithExtension: "tile", subdirectory: nil) ?? []
        return RecordedRadar(files: files, decoder: RadarTileDecoder(colorTable: try .universalBlue()))
    }

    func routeLine(from origin: GeoPoint, to destination: GeoPoint) async -> [GeoPoint] {
        await DirectionsService.routeLine(from: origin, to: destination)
    }
}
