import SolverKit
import SwiftUI

/// The best trade-offs between time and rain, or why no plan fits.
struct ResultsView: View {
    let result: PlanResult
    @State private var selectedID: String?

    private var selected: ScoredSchedule? {
        selectedID.flatMap(result.schedule(withID:)) ?? result.fastest
    }

    var body: some View {
        Group {
            switch result.outcome {
            case .infeasible(let reason):
                ContentUnavailableView(
                    "No Plan Fits",
                    systemImage: "clock.badge.xmark",
                    description: Text(PlanText.reason(reason))
                )
            case .frontier(let schedules):
                List {
                    Section {
                        ForecastNotice()
                    }

                    Section {
                        if let fastest = result.fastest, let driest = result.driest {
                            if fastest.id == driest.id {
                                ScheduleCard(title: "Best Plan", systemImage: "star", schedule: fastest)
                            } else {
                                ScheduleCard(title: "Fastest", systemImage: "hare", schedule: fastest)
                                ScheduleCard(title: "Driest", systemImage: "umbrella", schedule: driest)
                            }
                        }
                    }

                    if schedules.count > 1 {
                        Section {
                            TradeOffChart(schedules: schedules, selectedID: $selectedID)
                                .padding(.vertical, 8)
                        } header: {
                            Text("Time vs Rain")
                        } footer: {
                            Text("Each point is a plan that no other plan beats on both time and rain. Tap one to see it.")
                        }
                    }

                    if let selected {
                        Section {
                            RouteMapView(result: result, schedule: selected)
                                .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
                            NavigationLink(value: PlanRoute.itinerary(scheduleID: selected.id)) {
                                ScheduleRow(schedule: selected)
                            }
                        } header: {
                            Text("Selected Plan")
                        }
                    }

                    Section {
                        ForEach(schedules) { schedule in
                            NavigationLink(value: PlanRoute.itinerary(scheduleID: schedule.id)) {
                                ScheduleRow(schedule: schedule)
                            }
                        }
                    } header: {
                        Text("All Trade-offs")
                    }
                }
            }
        }
        .onAppear {
            if selectedID == nil { selectedID = result.fastest?.id }
        }
        .replayBanner()
        .navigationTitle("Results")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct ScheduleCard: View {
    let title: String
    let systemImage: String
    let schedule: ScoredSchedule

    var body: some View {
        NavigationLink(value: PlanRoute.itinerary(scheduleID: schedule.id)) {
            VStack(alignment: .leading, spacing: 6) {
                Label(title, systemImage: systemImage)
                    .font(.headline)
                Text("Leave at \(AppClock.time(schedule.departure))")
                    .font(.title3.weight(.semibold))
                Text("Back at \(AppClock.time(schedule.returnTime)) · \(PlanText.duration(schedule.returnTime.timeIntervalSince(schedule.departure))) out")
                    .foregroundStyle(.secondary)
                RainBadge(exposure: schedule.robustExposure)
            }
            .padding(.vertical, 4)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("plan-card")
    }
}

private struct ScheduleRow: View {
    let schedule: ScoredSchedule

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(AppClock.time(schedule.departure)) → \(AppClock.time(schedule.returnTime))")
                .font(.headline)
            Text(schedule.order.map(\.name).joined(separator: " → "))
                .font(.caption)
                .foregroundStyle(.secondary)
            RainBadge(exposure: schedule.robustExposure)
        }
        .accessibilityElement(children: .combine)
    }
}
