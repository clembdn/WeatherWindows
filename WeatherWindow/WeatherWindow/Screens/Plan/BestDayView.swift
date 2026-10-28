//
//  BestDayView.swift
//  WeatherWindow
//
//  Created by Clement Boudon on 19/10/2026.
//

import SwiftUI

struct BestDayView: View {
    let today: PlanResult

    @State private var model = BestDayViewModel()

    var body: some View {
        List {
            switch model.state {
            case .idle, .loading:
                ProgressView("Checking the next 7 days…")
            case .failed(let error):
                ErrorRow(error: error) {
                    Task { await model.load(from: today) }
                }
            case .loaded(let days):
                Section {
                    ForEach(days) { day in
                        NavigationLink {
                            ResultsView(result: day.result, showsOtherDays: false)
                        } label: {
                            DayRow(day: day, isBest: day.id == model.bestDay?.id)
                        }
                    }
                } footer: {
                    Text("Same errands and departure window every day. Only the days covered by the forecast are shown, and forecasts get less certain after 3 days.")
                        .foregroundStyle(.secondaryText)
                }
            }
        }
        .navigationTitle("Next 7 Days")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await model.load(from: today)
        }
    }
}

private struct DayRow: View {
    let day: PlanDay
    let isBest: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if isBest {
                Label("Driest Day", systemImage: "star.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tint)
            }
            Text(day.day.formatted(Date.FormatStyle(timeZone: Melbourne.timeZone).weekday(.wide).day().month(.wide)))
                .font(.headline)
            if let driest = day.result.driest {
                Text("Leave at \(Melbourne.time(driest.departure)) · back at \(Melbourne.time(driest.returnTime))")
                    .foregroundStyle(.secondaryText)
                RainBadge(exposure: driest.robustExposure)
            } else {
                Text("No plan fits the opening hours.")
                    .foregroundStyle(.secondaryText)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
