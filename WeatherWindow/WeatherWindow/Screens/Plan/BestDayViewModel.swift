//
//  BestDayViewModel.swift
//  WeatherWindow
//
//  Created by Clement Boudon on 19/10/2026.
//

import Foundation

struct PlanDay: Identifiable {
    let day: Date
    let result: PlanResult

    var id: Date { day }
}

@Observable
final class BestDayViewModel {
    private(set) var state = LoadState<[PlanDay]>.idle

    var bestDay: PlanDay? {
        guard case .loaded(let days) = state else { return nil }
        let possibleDays = days.filter { $0.result.driest != nil }
        return possibleDays.min { ($0.result.driest?.robustExposure ?? 0) < ($1.result.driest?.robustExposure ?? 0) }
    }

    func load(from today: PlanResult) async {
        if case .loaded = state {
            return
        }
        state = .loading

        do {
            let data = today.data
            let walkingTimes = try await data.walkingTimes(start: today.start.location, end: today.end.location,
                                                           stops: today.stops)
            let centre = GeoPoint.centroid(of: today.stops.map(\.location)) ?? today.start.location
            let forecast = HourlyForecast(hours: try await data.hourlyForecast(at: centre))
            let scenarios = ShiftedForecast.scenarios(around: forecast)
            let lastHour = forecast.hours.last?.time ?? today.departureWindow.upperBound

            let calendar = Melbourne.calendar
            var days: [PlanDay] = []
            for dayNumber in 0..<7 {
                guard let start = calendar.date(byAdding: .day, value: dayNumber, to: today.departureWindow.lowerBound),
                      let end = calendar.date(byAdding: .day, value: dayNumber, to: today.departureWindow.upperBound),
                      end <= lastHour else { break }

                let request = PlanRequest(
                    start: today.start.location,
                    end: today.end.location,
                    stops: today.stops,
                    departureWindow: start...end,
                    walkingTimes: walkingTimes,
                    timeZone: Melbourne.timeZone
                )
                let outcome = await DayPlanViewModel.rankSchedules(request, scenarios: scenarios)
                let result = PlanResult(outcome: outcome, start: today.start, end: today.end, endsAtStart: today.endsAtStart,
                                        errands: today.errands, stops: today.stops, scenarios: scenarios, usesEnsemble: false,
                                        data: data, departureWindow: start...end)
                days.append(PlanDay(day: start, result: result))
            }
            state = .loaded(days)
        } catch {
            let serviceError = ServiceError(error)
            if serviceError != .cancelled {
                state = .failed(serviceError)
            }
        }
    }
}
