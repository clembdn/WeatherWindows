import SwiftUI

/// A saved day, read back from SwiftData exactly as it was planned.
struct SavedPlanView: View {
    let plan: DayPlan

    var body: some View {
        List {
            Section {
                LabeledContent("Start", value: plan.startName)
                LabeledContent("End", value: plan.endName ?? plan.startName)
                if let departure = plan.departure {
                    LabeledContent("Leave", value: AppClock.time(departure))
                }
                if let returnTime = plan.returnTime {
                    LabeledContent("Back", value: AppClock.time(returnTime))
                }
                if let exposure = plan.robustExposure {
                    RainBadge(exposure: exposure)
                }
            }

            Section("Errands") {
                ForEach(plan.orderedStops) { stop in
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(stop.rank + 1). \(stop.name)")
                            .font(.headline)
                        if let arrival = stop.arrival, let departure = stop.departure {
                            Text("\(AppClock.time(arrival)) – \(AppClock.time(departure))")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .navigationTitle(plan.date.formatted(date: .abbreviated, time: .omitted))
        .navigationBarTitleDisplayMode(.inline)
    }
}
