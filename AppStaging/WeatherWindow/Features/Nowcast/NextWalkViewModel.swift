import ForecastKit
import Foundation
import NowcastKit
import SolverKit
import WeatherWindowCore

/// Where you are and what is left to do.
struct NextWalkInput {
    let current: Place
    let remaining: [Stop]
    let end: Place
}

/// The radar check: advice for leaving, and the data behind the collision view.
struct NextWalkResult {
    let now: Date
    let input: NextWalkInput
    let advice: DepartureAdvice
    let nowcast: Nowcast?
    /// Shown when the radar could not be used and the hourly forecast took over.
    let radarNotice: String?

    /// The schedule the advice recommends: waiting if worth it, otherwise leaving now.
    var recommended: ScoredSchedule? { advice.bestLater ?? advice.leaveNow }

    func name(of node: Node) -> String {
        switch node {
        case .start: input.current.name
        case .end: input.end.name
        case .stop(let id): input.remaining.first { $0.id == id }?.name ?? "Errand"
        }
    }
}

/// Re-plans the rest of the day from here over the next 30 minutes, with the radar nowcast.
@Observable
final class NextWalkViewModel {
    let input: NextWalkInput
    private(set) var state = LoadState<NextWalkResult>.idle
    /// Collision view time, in minutes from now (−30 to +30).
    var minuteOffset = 0.0

    static let adviceWindow: TimeInterval = 30 * 60

    init(input: NextWalkInput) {
        self.input = input
    }

    func load(services: PlanServices) async {
        if case .loaded = state {} else { state = .loading }

        do {
            let now = services.now()
            let points = [input.current.location] + input.remaining.map(\.location) + [input.end.location]
            let walkingTimes = try await services.walkingTimes(input.current.location, input.end.location, input.remaining)
            let centre = GeoPoint.centroid(of: points) ?? input.current.location
            let hourly = HourlyRainField(samples: try await services.hourlyForecast(centre))

            var radarNotice: String?
            var frames: [RadarFrame] = []
            do {
                frames = try await services.radarFrames(now)
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                radarNotice = "Radar unavailable (\(ServiceError(error).errorDescription ?? "")). Using the hourly forecast only."
            }

            let outcome = await Self.makeNowcast(frames: frames, points: points, now: now, fallback: hourly)
            var nowcast: Nowcast?
            switch outcome {
            case .ready(let ready):
                nowcast = ready
            case .stale(let last):
                radarNotice = "The latest radar image is from \(AppClock.time(last)), too old to use. Using the hourly forecast only."
            case .noFrames:
                radarNotice = radarNotice ?? "No radar images are available. Using the hourly forecast only."
            }

            let request = PlanRequest(
                start: input.current.location,
                end: input.end.location,
                stops: input.remaining,
                departureWindow: now...now.addingTimeInterval(Self.adviceWindow),
                walkingTimes: walkingTimes,
                timeZone: AppClock.timeZone
            )
            let field: any RainField = nowcast?.field ?? hourly
            let advice = await Self.advise(request, field: field)
            state = .loaded(NextWalkResult(now: now, input: input, advice: advice, nowcast: nowcast, radarNotice: radarNotice))
        } catch is CancellationError {
            return
        } catch {
            state = .failed(ServiceError(error))
        }
    }

    /// Motion estimation and 30 extrapolated minutes, off the main actor.
    @concurrent
    private static func makeNowcast(frames: [RadarFrame], points: [GeoPoint], now: Date,
                                    fallback: any RainField) async -> NowcastOutcome {
        NowcastEngine.make(frames: frames, around: points, now: now, fallback: fallback)
    }

    @concurrent
    private static func advise(_ request: PlanRequest, field: any RainField) async -> DepartureAdvice {
        DepartureAdvisor.advice(for: request, scenarios: [field])
    }
}
