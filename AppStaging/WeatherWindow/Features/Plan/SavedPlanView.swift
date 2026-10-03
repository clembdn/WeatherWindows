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

            Section {
                ForEach(-1..<plan.orderedStops.count, id: \.self) { index in
                    NavigationLink {
                        NextWalkView(input: input(after: index))
                    } label: {
                        Text("At \(index < 0 ? plan.startName : plan.orderedStops[index].name)")
                    }
                }
            } header: {
                Text("On the Way")
            } footer: {
                Text("Where are you? Check the radar for the next walk.")
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

    /// The rest of the day from the start (index −1) or from a stop.
    private func input(after index: Int) -> NextWalkInput {
        let stops = plan.orderedStops
        let current = index < 0
            ? Place(name: plan.startName, location: plan.start)
            : Place(name: stops[index].name, location: stops[index].location)
        return NextWalkInput(
            current: current,
            remaining: stops.dropFirst(index + 1).map { $0.makeStop() },
            end: Place(name: plan.endName ?? plan.startName, location: plan.end)
        )
    }
}
