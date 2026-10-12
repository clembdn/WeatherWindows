import SolverKit
import SwiftData
import SwiftUI

// The chosen schedule step by step: each walk with its rain, each errand with arrival, wait and departure.
struct ItineraryView: View {
    let result: PlanResult
    let schedule: ScoredSchedule

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
                NavigationLink {
                    NextWalkView(input: NextWalkInput(current: result.start, remaining: schedule.order, end: result.end),
                                 data: result.data)
                } label: {
                    Label("Check the Radar Before Leaving", systemImage: "cloud.sun.rain")
                }
                .accessibilityIdentifier("check-radar")
                Button("Remind Me to Leave at \(Melbourne.time(schedule.departure))", systemImage: "bell") {
                    remind()
                }
                if let reminderMessage {
                    Text(reminderMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                if notifications.isDenied {
                    NotificationSettingsButton()
                }
            }

            Section {
                RouteMapView(result: result, schedule: schedule)
                    .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
            }

            Section("Steps") {
                LabeledContent {
                    Text(Melbourne.time(schedule.departure))
                } label: {
                    Label("Leave \(result.start.name)", systemImage: "figure.walk.departure")
                }

                ForEach(schedule.legs.indices, id: \.self) { index in
                    LegRow(leg: schedule.legs[index], destination: result.name(of: schedule.legs[index].to))
                    if index < schedule.visits.count {
                        VisitRow(visit: schedule.visits[index])
                    }
                }

                LabeledContent {
                    Text(Melbourne.time(schedule.returnTime))
                } label: {
                    Label("Arrive at \(result.end.name)", systemImage: "house")
                }
            }

            Section {
                ForecastNotice()
            }

            Section {
                if isSaved {
                    Label("Plan saved", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    Button("Save This Plan", systemImage: "square.and.arrow.down", action: save)
                }
                ValidationMessage(text: saveErrorMessage)
            }
        }
        .navigationTitle("Itinerary")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            isSaved = result.isSaved(schedule, in: context)
        }
    }

    // The plan id is the reminder id, so asking again replaces the reminder instead of adding a second one.
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
                .foregroundStyle(.secondary)
                .padding(.leading, 28)
        }
        .accessibilityElement(children: .combine)
    }
}
