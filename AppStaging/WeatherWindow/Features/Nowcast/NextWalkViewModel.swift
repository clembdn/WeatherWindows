import ForecastKit
import Foundation
import NowcastKit
import SolverKit
import WeatherWindowCore

// Where you are and what is left to do.
struct NextWalkInput {
    let current: Place
    let remaining: [Stop]
    let end: Place
}

// The radar check: advice for leaving, and the data behind the collision view.
struct NextWalkResult {
    let now: Date
    let input: NextWalkInput
    let advice: DepartureAdvice
    let nowcast: Nowcast?
    // Shown when the radar could not be used and the hourly forecast took over.
    let radarNotice: String?

    // Waiting if it is worth it, otherwise leaving now.
    var recommended: ScoredSchedule? { advice.bestLater ?? advice.leaveNow }

    func name(of node: Node) -> String {
        switch node {
        case .start: input.current.name
        case .end: input.end.name
        case .stop(let id): input.remaining.first { $0.id == id }?.name ?? "Errand"
        }
    }
}

// Re-plans the rest of the day from here over the next 30 minutes, with the radar nowcast.
@Observable
final class NextWalkViewModel {
    let input: NextWalkInput
    private(set) var state = LoadState<NextWalkResult>.idle
    // Time shown by the collision view, in minutes from now (−30 to +30).
    var minuteOffset = 0.0

    init(input: NextWalkInput) {
        self.input = input
    }

    func load(data: any PlanDataSource) async {
        switch state {
        case .loaded:
            break // keep the last advice on screen while the radar refreshes
        default:
            state = .loading
        }

        do {
            let now = data.now
            let points = [input.current.location] + input.remaining.map(\.location) + [input.end.location]
            let walkingTimes = try await data.walkingTimes(start: input.current.location, end: input.end.location,
                                                           stops: input.remaining)
            let centre = GeoPoint.centroid(of: points) ?? input.current.location
            let hourly = HourlyRainField(samples: try await data.hourlyForecast(at: centre))
            // Without radar images the advice still works, from the hourly forecast alone.
            let frames = (try? await data.radarFrames(upTo: now)) ?? []

            let request = PlanRequest(
                start: input.current.location,
                end: input.end.location,
                stops: input.remaining,
                departureWindow: now...now.addingTimeInterval(30 * 60),
                walkingTimes: walkingTimes,
                timeZone: Melbourne.timeZone
            )
            let (outcome, advice) = await Self.advise(request, frames: frames, points: points, now: now, hourly: hourly)

            var nowcast: Nowcast?
            var radarNotice: String?
            switch outcome {
            case .ready(let ready):
                nowcast = ready
            case .stale(let last):
                radarNotice = "The latest radar image is from \(Melbourne.time(last)), too old to use. Using the hourly forecast only."
            case .noFrames:
                radarNotice = "No radar images are available. Using the hourly forecast only."
            case .outsideRadar:
                radarNotice = "The radar only covers the Melbourne area. Using the hourly forecast only."
            }
            state = .loaded(NextWalkResult(now: now, input: input, advice: advice, nowcast: nowcast, radarNotice: radarNotice))
        } catch {
            let serviceError = ServiceError(error)
            if serviceError != .cancelled {
                state = .failed(serviceError)
            }
        }
    }

    // Measuring the motion, extrapolating 30 minutes and running the solver are heavy: off the main thread.
    @concurrent
    private static func advise(_ request: PlanRequest, frames: [RadarFrame], points: [GeoPoint], now: Date,
                               hourly: HourlyRainField) async -> (NowcastOutcome, DepartureAdvice) {
        let outcome = NowcastEngine.make(frames: frames, around: points, now: now, fallback: hourly)
        var field: any RainField = hourly
        if case .ready(let nowcast) = outcome {
            field = nowcast.field
        }
        return (outcome, DepartureAdvisor.advice(for: request, scenarios: [field]))
    }
}
