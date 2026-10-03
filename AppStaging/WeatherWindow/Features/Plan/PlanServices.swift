import ForecastKit
import Foundation
import NowcastKit
import SolverKit
import SwiftData
import WeatherWindowCore

/// The outside world the planner needs, injected so tests and the replay never touch the network.
struct PlanServices {
    var now: () -> Date = { Date() }
    var currentLocation: () async throws -> GeoPoint
    var walkingTimes: (_ start: GeoPoint, _ end: GeoPoint, _ stops: [Stop]) async throws -> [Node: [Node: TimeInterval]]
    var hourlyForecast: (_ point: GeoPoint) async throws -> [WeatherSample]
    /// The latest radar frames at or before a time, oldest first.
    var radarFrames: (_ time: Date) async throws -> [RadarFrame] = { _ in [] }

    /// Frames used to measure motion: three pairs.
    static let radarFrameCount = 4

    static func current(isReplay: Bool, context: ModelContext, location: LocationService, paceFactor: Double) -> PlanServices {
        isReplay ? .replay() : .live(context: context, location: location, paceFactor: paceFactor)
    }

    static func live(context: ModelContext, location: LocationService, paceFactor: Double) -> PlanServices {
        PlanServices(
            currentLocation: { try await location.currentLocation() },
            walkingTimes: { start, end, stops in
                let builder = WalkingMatrixBuilder(context: context, paceFactor: paceFactor)
                return try await builder.walkingTimes(start: start, end: end, stops: stops).walkingTimes
            },
            hourlyForecast: { point in try await OpenMeteoService().hourlyForecast(at: point) },
            radarFrames: { time in try await LiveRainViewerSource.shared.frames(upTo: time, count: radarFrameCount) }
        )
    }

    /// Typical walking speed used offline, in metres per second (≈ 4.7 km/h).
    static let straightLineWalkingSpeed = 1.3

    /// The recorded morning, fully offline: frozen clock, recorded radar and forecast, straight-line walks.
    static func replay() -> PlanServices {
        PlanServices(
            now: { ReplaySession.now },
            currentLocation: { .melbourneCBD },
            walkingTimes: { start, end, stops in straightLineWalkingTimes(start: start, end: end, stops: stops) },
            hourlyForecast: { _ in try ReplaySession.forecast() },
            radarFrames: { time in try await ReplaySession.frameSource().frames(upTo: time, count: radarFrameCount) }
        )
    }

    static func straightLineWalkingTimes(start: GeoPoint, end: GeoPoint, stops: [Stop]) -> [Node: [Node: TimeInterval]] {
        var places: [Node: GeoPoint] = [.start: start, .end: end]
        for stop in stops { places[.stop(stop.id)] = stop.location }

        var matrix: [Node: [Node: TimeInterval]] = [:]
        for (from, to) in WalkingMatrixBuilder.edges(for: stops) {
            guard let origin = places[from], let destination = places[to] else { continue }
            matrix[from, default: [:]][to] = origin.distance(to: destination) / straightLineWalkingSpeed
        }
        return matrix
    }
}
