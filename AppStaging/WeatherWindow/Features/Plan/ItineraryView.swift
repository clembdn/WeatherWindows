import SolverKit
import SwiftData
import SwiftUI
import UIKit

/// The chosen schedule step by step: each walk with its rain, each errand with arrival, wait and departure.
struct ItineraryView: View {
    let model: DayPlanViewModel
    let result: PlanResult
    let schedule: ScoredSchedule

    @Environment(\.modelContext) private var context
    @Environment(NotificationService.self) private var notifications
    @Environment(\.openURL) private var openURL
    @State private var isSaved = false
    @State private var reminderMessage: String?
    @State private var saveErrorMessage: String?

    var body: some View {
        List {
            Section {
                LabeledContent("Leave", value: AppClock.time(schedule.departure))
                LabeledContent("Back", value: AppClock.time(schedule.returnTime))
                LabeledContent("Time out", value: PlanText.duration(schedule.returnTime.timeIntervalSince(schedule.departure)))
                RainBadge(exposure: schedule.robustExposure)
                Button("Remind Me to Leave at \(AppClock.time(schedule.departure))", systemImage: "bell") {
                    Task { await remind() }
                }
                if let reminderMessage {
                    Text(reminderMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                if notifications.isDenied {
                    Button("Turn On Notifications in Settings", systemImage: "gear") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                    }
                }
            }

            Section {
                RouteMapView(result: result, schedule: schedule)
                    .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
            }

            Section("Steps") {
                StepRow(systemImage: "figure.walk.departure", title: "Leave \(result.start.name)",
                        detail: AppClock.time(schedule.departure))

                ForEach(Array(schedule.legs.enumerated()), id: \.offset) { index, leg in
                    LegRow(leg: leg, destination: result.name(of: leg.to))
                    if index < schedule.visits.count {
                        VisitRow(visit: schedule.visits[index])
                    }
                }

                StepRow(systemImage: "house", title: "Arrive at \(result.end.name)",
                        detail: AppClock.time(schedule.returnTime))
            }

            Section {
                NavigationLink {
                    NextWalkView(input: NextWalkInput(current: result.start, remaining: schedule.order, end: result.end))
                } label: {
                    Label("Check the Radar Before Leaving", systemImage: "cloud.sun.rain")
                }
                .accessibilityIdentifier("check-radar")
                ForecastNotice()
            }

            Section {
                if isSaved {
                    Label("Plan saved", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    Button("Save This Plan", systemImage: "square.and.arrow.down", action: save)
                }
                if let saveErrorMessage {
                    ValidationMessage(text: saveErrorMessage)
                }
            }
        }
        .navigationTitle("Itinerary")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// One reminder per plan: scheduling again replaces it instead of adding a second one.
    private func remind() async {
        let scheduled = await notifications.scheduleReminder(
            id: "plan-\(schedule.id)",
            at: schedule.departure,
            title: "Time to leave",
            body: "Leave now for \(schedule.order.map(\.name).joined(separator: ", ")). \(PlanText.rain(schedule.robustExposure))."
        )
        reminderMessage = scheduled
            ? "Reminder set for \(AppClock.time(schedule.departure))."
            : "Notifications are off, so no reminder was set."
    }

    private func save() {
        do {
            try model.save(schedule, from: result, in: context)
            isSaved = true
            saveErrorMessage = nil
        } catch {
            saveErrorMessage = "The plan couldn't be saved. \(error.localizedDescription)"
        }
    }
}

private struct StepRow: View {
    let systemImage: String
    let title: String
    let detail: String

    var body: some View {
        LabeledContent {
            Text(detail)
        } label: {
            Label(title, systemImage: systemImage)
        }
    }
}

private struct LegRow: View {
    let leg: Leg
    let destination: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("Walk \(PlanText.duration(leg.arrival.timeIntervalSince(leg.departure))) to \(destination)",
                  systemImage: "figure.walk")
            RainBadge(exposure: leg.exposureByScenario.max() ?? 0)
                .padding(.leading, 28)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct VisitRow: View {
    let visit: Visit

    private var detail: String {
        var parts = ["Arrive \(AppClock.time(visit.arrival))"]
        if visit.waiting >= 60 {
            parts.append("wait \(PlanText.duration(visit.waiting))")
        }
        parts.append("leave \(AppClock.time(visit.departure))")
        return parts.joined(separator: " · ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Label(visit.stop.name, systemImage: "mappin.circle.fill")
                .font(.headline)
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.leading, 28)
        }
        .accessibilityElement(children: .combine)
    }
}
