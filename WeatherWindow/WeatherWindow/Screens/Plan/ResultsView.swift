//
//  ResultsView.swift
//  WeatherWindow
//
//  Created by Clement Boudon on 7/10/2026.
//

import SwiftData
import SwiftUI

struct ResultsView: View {
    let result: PlanResult
    var showsOtherDays = true
    @Query private var savedPlans: [DayPlan]
    @State private var selectedID: String?

    private var usual: Schedule? {
        result.usualChoice(savedTradeOffs: savedPlans.map(\.tradeOff))
    }

    private var selected: Schedule? {
        result.schedules.first { $0.id == selectedID } ?? usual ?? result.fastest
    }

    var body: some View {
        Group {
            switch result.outcome {
            case .noPlan(let reason):
                ContentUnavailableView("No Plan Fits", systemImage: "clock.badge.xmark",
                                       description: Text(PlanText.reason(reason)))
            case .schedules(let schedules):
                List {
                    Section {
                        ForecastNotice(usesEnsemble: result.usesEnsemble)
                    }

                    if let fastest = result.fastest, let driest = result.driest {
                        Section {
                            if fastest.id == driest.id {
                                ScheduleCard(title: "Best Plan", systemImage: "star", result: result, schedule: fastest)
                            } else {
                                ScheduleCard(title: "Fastest", systemImage: "hare", result: result, schedule: fastest)
                                ScheduleCard(title: "Driest", systemImage: "umbrella", result: result, schedule: driest)
                            }
                            if let usual, usual.id != fastest.id, usual.id != driest.id {
                                ScheduleCard(title: "Your Usual Choice", systemImage: "person.crop.circle.badge.checkmark",
                                             result: result, schedule: usual)
                            }
                        }
                    }

                    if showsOtherDays {
                        Section {
                            NavigationLink {
                                BestDayView(today: result)
                            } label: {
                                Label("Compare the Next 7 Days", systemImage: "calendar")
                            }
                        }
                    }

                    if schedules.count > 1 {
                        Section {
                            TradeOffChart(schedules: schedules, selectedID: $selectedID)
                                .padding(.vertical, 8)
                        } header: {
                            Text("Time vs Rain")
                                .foregroundStyle(.secondaryText)
                        } footer: {
                            Text("Each point is a plan that no other plan beats on both time and rain. Tap one to see it.")
                                .foregroundStyle(.secondaryText)
                        }
                    }

                    if let selected {
                        Section {
                            RouteMapView(result: result, schedule: selected)
                                .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
                            NavigationLink {
                                ItineraryView(result: result, schedule: selected)
                            } label: {
                                ScheduleRow(schedule: selected)
                            }
                        } header: {
                            Text("Selected Plan")
                                .foregroundStyle(.secondaryText)
                        }
                    }

                    Section {
                        ForEach(schedules) { schedule in
                            NavigationLink {
                                ItineraryView(result: result, schedule: schedule)
                            } label: {
                                ScheduleRow(schedule: schedule)
                            }
                        }
                    } header: {
                        Text("All Trade-offs")
                            .foregroundStyle(.secondaryText)
                    }
                }
            }
        }
        .navigationTitle("Results")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { selectedID = selected?.id }
    }
}

private struct ScheduleCard: View {
    let title: String
    let systemImage: String
    let result: PlanResult
    let schedule: Schedule

    var body: some View {
        NavigationLink {
            ItineraryView(result: result, schedule: schedule)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Label(title, systemImage: systemImage)
                    .font(.headline)
                Text("Leave at \(Melbourne.time(schedule.departure))")
                    .font(.title3.weight(.semibold))
                Text("Back at \(Melbourne.time(schedule.returnTime)) · \(PlanText.duration(schedule.returnTime.timeIntervalSince(schedule.departure))) out")
                    .foregroundStyle(.secondaryText)
                RainBadge(exposure: schedule.robustExposure)
                ConfidenceBadge(level: schedule.confidence)
            }
            .padding(.vertical, 4)
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens the itinerary.")
        .accessibilityIdentifier("plan-card")
    }
}

private struct ScheduleRow: View {
    let schedule: Schedule

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(Melbourne.time(schedule.departure)) → \(Melbourne.time(schedule.returnTime))")
                .font(.headline)
            Text(schedule.order.map(\.name).joined(separator: " → "))
                .font(.caption)
                .foregroundStyle(.secondaryText)
            RainBadge(exposure: schedule.robustExposure)
        }
        .accessibilityElement(children: .combine)
    }
}
