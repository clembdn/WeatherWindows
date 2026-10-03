import SolverKit
import SwiftUI

/// The best trade-offs between time and rain, or why no plan fits.
struct ResultsView: View {
    let result: PlanResult

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

                    Section {
                        ForEach(schedules) { schedule in
                            NavigationLink(value: PlanRoute.itinerary(scheduleID: schedule.id)) {
                                ScheduleRow(schedule: schedule)
                            }
                        }
                    } header: {
                        Text("All Trade-offs")
                    } footer: {
                        Text("No plan in this list is both faster and drier than another.")
                    }
                }
            }
        }
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
