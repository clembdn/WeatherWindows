//
//  ItineraryView.swift
//  WeatherWindow
//
//  Created by Clement Boudon on 7/10/2026.
//

import SwiftData
import SwiftUI

struct ItineraryView: View {
    let result: PlanResult
    let schedule: Schedule

    @Environment(\.modelContext) private var context
    @Environment(NotificationService.self) private var notifications
    @State private var isSaved = false
    @State private var reminderMessage: String?
    @State private var saveErrorMessage: String?

    var body: some View {
        List {
            Section {
                LabeledContent("Leave", value: Melbourne.time(schedule.departure))
                LabeledContent("Back", value: Melbourne.time(schedule.returnTime))
                LabeledContent("Time out", value: PlanText.duration(schedule.returnTime.timeIntervalSince(schedule.departure)))
                RainBadge(exposure: schedule.robustExposure)
                ConfidenceBadge(level: schedule.confidence)
                NavigationLink {
                    NextWalkView(input: NextWalkInput(current: result.start, remaining: schedule.order, end: result.end),
                                 data: result.data)
                } label: {
                    Label("Check the Radar Before Leaving", systemImage: "cloud.sun.rain")
                }
                .accessibilityHint("Shows the rain radar along your next walk.")
                .accessibilityIdentifier("check-radar")
                Button("Remind Me to Leave at \(Melbourne.time(schedule.departure))", systemImage: "bell") {
                    remind()
                }
                .accessibilityHint("Sends you a notification at that time.")
                if let reminderMessage {
                    Text(reminderMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondaryText)
                }
                if notifications.isDenied {
                    NotificationSettingsButton()
                }
            }

            Section {
                RouteMapView(result: result, schedule: schedule)
                    .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
            }

            Section {
                LabeledContent {
                    Text(Melbourne.time(schedule.departure))
                } label: {
                    Label("Leave \(result.start.name)", systemImage: "figure.walk.departure")
                }

                ForEach(schedule.walks.indices, id: \.self) { index in
                    WalkRow(walk: schedule.walks[index], destination: result.name(of: schedule.walks[index].to))
                    if index < schedule.visits.count {
                        VisitRow(visit: schedule.visits[index])
                    }
                }

                LabeledContent {
                    Text(Melbourne.time(schedule.returnTime))
                } label: {
                    Label("Arrive at \(result.end.name)", systemImage: "house")
                }
            } header: {
                Text("Steps")
                    .foregroundStyle(.secondaryText)
            }

            Section {
                ForecastNotice(usesEnsemble: result.usesEnsemble)
            }

            Section {
                if isSaved {
                    Label("Plan saved", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.successGreen)
                } else {
                    Button("Save This Plan", systemImage: "square.and.arrow.down", action: save)
                        .accessibilityHint("Adds it to Saved Plans on the Plan tab.")
                }
                ValidationMessage(text: saveErrorMessage)
            }
        }
        .navigationTitle("Itinerary")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ShareLink(item: result.shareText(for: schedule))
        }
        .onAppear {
            isSaved = result.isSaved(schedule, in: context)
        }
    }

    private func remind() {
        let names = schedule.order.map(\.name).joined(separator: ", ")
        Task {
            reminderMessage = await notifications.scheduleReminder(
                id: "plan-\(schedule.id)",
                at: schedule.departure,
                body: "Leave now for \(names). \(PlanText.rain(schedule.robustExposure))."
            )
        }
    }

    private func save() {
        do {
            try result.save(schedule, in: context)
            isSaved = true
            saveErrorMessage = nil
        } catch {
            saveErrorMessage = "The plan couldn't be saved. \(error.localizedDescription)"
        }
    }
}

private struct WalkRow: View {
    let walk: Walk
    let destination: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("Walk \(PlanText.duration(walk.arrival.timeIntervalSince(walk.departure))) to \(destination)",
                  systemImage: "figure.walk")
            RainBadge(exposure: walk.exposureByScenario.max() ?? 0)
                .padding(.leading, 28)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct VisitRow: View {
    let visit: Visit

    private var detail: String {
        var text = "Arrive \(Melbourne.time(visit.arrival))"
        if visit.waiting >= 60 {
            text += " · wait \(PlanText.duration(visit.waiting))"
        }
        return text + " · leave \(Melbourne.time(visit.departure))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Label(visit.stop.name, systemImage: "mappin.circle.fill")
                .font(.headline)
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(.secondaryText)
                .padding(.leading, 28)
        }
        .accessibilityElement(children: .combine)
    }
}
