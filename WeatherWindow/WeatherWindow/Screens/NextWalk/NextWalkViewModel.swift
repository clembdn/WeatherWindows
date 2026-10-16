//
//  NextWalkViewModel.swift
//  WeatherWindow
//
//  Created by Clement Boudon on 7/10/2026.
//

import Foundation

struct NextWalkInput {
    let current: Place
    let remaining: [Stop]
    let end: Place
}

struct NextWalkResult {
    let now: Date
    let input: NextWalkInput
    let advice: DepartureAdvice
    let nowcast: Nowcast?
    let radarNotice: String?

    var recommended: Schedule? { advice.bestLater ?? advice.leaveNow }

    func name(of waypoint: Waypoint) -> String {
        switch waypoint {
        case .start: input.current.name
        case .end: input.end.name
        case .stop(let id): input.remaining.first { $0.id == id }?.name ?? "Errand"
        }
    }
}

@Observable
final class NextWalkViewModel {
    let input: NextWalkInput
    private(set) var state = LoadState<NextWalkResult>.idle
    var minuteOffset = 0.0
    var alertsWhenRainComes = false
    @ObservationIgnored private var foundRain = false

    init(input: NextWalkInput) {
        self.input = input
    }

    func load(data: any PlanDataSource) async {
        switch state {
        case .loaded:
            break
        default:
            state = .loading
        }

        do {
            let now = data.now
            let points = [input.current.location] + input.remaining.map(\.location) + [input.end.location]
            let walkingTimes = try await data.walkingTimes(start: input.current.location, end: input.end.location,
                                                           stops: input.remaining)
            let centre = GeoPoint.centroid(of: points) ?? input.current.location
            let hourly = HourlyForecast(hours: try await data.hourlyForecast(at: centre))
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

    func rainAlert() -> String? {
        guard alertsWhenRainComes, case .loaded(let result) = state,
              let leaveNow = result.advice.leaveNow, let walk = leaveNow.walks.first else { return nil }
        let isRainy = !PlanText.isDry(walk.exposureByScenario.max() ?? 0)
        let alreadyFound = foundRain
        foundRain = isRainy
        if !isRainy || alreadyFound {
            return nil
        }

        var text = "Rain is expected on your walk to \(result.name(of: walk.to))."
        if let later = result.advice.bestLater {
            text += " Leave at \(Melbourne.time(later.departure)) to stay drier."
        }
        return text
    }

    @concurrent
    private static func advise(_ request: PlanRequest, frames: [RadarFrame], points: [GeoPoint], now: Date,
                               hourly: HourlyForecast) async -> (NowcastOutcome, DepartureAdvice) {
        let outcome = NowcastMaker.make(frames: frames, around: points, now: now, fallback: hourly)
        var forecast: any RainForecast = hourly
        if case .ready(let nowcast) = outcome {
            forecast = nowcast.rainForecast
        }
        return (outcome, DepartureAdvisor.advice(for: request, scenarios: [forecast]))
    }
}
