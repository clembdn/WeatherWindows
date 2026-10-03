import ForecastKit
import Foundation
import SolverKit
import SwiftData
import WeatherWindowCore

/// The outside world the planner needs, injected so tests and screenshots never touch the network.
struct PlanServices {
    var currentLocation: () async throws -> GeoPoint
    var walkingTimes: (_ start: GeoPoint, _ end: GeoPoint, _ stops: [Stop]) async throws -> [Node: [Node: TimeInterval]]
    var hourlyForecast: (_ point: GeoPoint) async throws -> [WeatherSample]

    static func live(context: ModelContext, location: LocationService, paceFactor: Double) -> PlanServices {
        PlanServices(
            currentLocation: { try await location.currentLocation() },
            walkingTimes: { start, end, stops in
                let builder = WalkingMatrixBuilder(context: context, paceFactor: paceFactor)
                return try await builder.walkingTimes(start: start, end: end, stops: stops).walkingTimes
            },
            hourlyForecast: { point in try await OpenMeteoService().hourlyForecast(at: point) }
        )
    }

    /// Typical walking speed used by the offline stand-in, in metres per second (≈ 4.7 km/h).
    static let sampleWalkingSpeed = 1.3

    /// Offline stand-in for UI tests and screenshots: straight-line walks and a shower during the next hour.
    static func sample(now: Date = .now) -> PlanServices {
        PlanServices(
            currentLocation: { .melbourneCBD },
            walkingTimes: { start, end, stops in
                var places: [Node: GeoPoint] = [.start: start, .end: end]
                for stop in stops { places[.stop(stop.id)] = stop.location }

                var matrix: [Node: [Node: TimeInterval]] = [:]
                for (from, to) in WalkingMatrixBuilder.edges(for: stops) {
                    guard let origin = places[from], let destination = places[to] else { continue }
                    matrix[from, default: [:]][to] = origin.distance(to: destination) / sampleWalkingSpeed
                }
                return matrix
            },
            hourlyForecast: { _ in
                let hourStart = AppClock.calendar.dateInterval(of: .hour, for: now)?.start ?? now
                return (1...48).map { offset in
                    let isShower = offset == 2
                    return WeatherSample(
                        time: hourStart.addingTimeInterval(TimeInterval(offset) * 3600),
                        precipitationProbability: isShower ? 90 : 5,
                        precipitation: isShower ? 2 : 0
                    )
                }
            }
        )
    }
}
