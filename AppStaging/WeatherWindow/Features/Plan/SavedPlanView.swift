import SwiftUI

// A saved day, read back from SwiftData exactly as it was planned.
struct SavedPlanView: View {
    let plan: DayPlan
    let data: any PlanDataSource

    var body: some View {
        List {
            Section {
                LabeledContent("Start", value: plan.start.name)
                LabeledContent("End", value: plan.end.name)
                LabeledContent("Leave", value: Melbourne.time(plan.departure))
                LabeledContent("Back", value: Melbourne.time(plan.returnTime))
                RainBadge(exposure: plan.robustExposure)
            }

            Section {
                NavigationLink("At \(plan.start.name)") {
                    NextWalkView(input: nextWalk(after: nil), data: data)
                }
                ForEach(plan.orderedStops) { stop in
                    NavigationLink("At \(stop.name)") {
                        NextWalkView(input: nextWalk(after: stop), data: data)
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
                        Text("\(Melbourne.time(stop.arrival)) – \(Melbourne.time(stop.departure))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .navigationTitle(plan.departure.formatted(date: .abbreviated, time: .omitted))
        .navigationBarTitleDisplayMode(.inline)
    }

    // The rest of the day, from the start (nil) or from the errand just finished.
    private func nextWalk(after stop: PlannedStop?) -> NextWalkInput {
        var current = plan.start
        var remaining = plan.orderedStops
        if let stop {
            current = Place(name: stop.name, location: stop.location)
            remaining = remaining.filter { $0.rank > stop.rank }
        }
        return NextWalkInput(current: current, remaining: remaining.map { $0.makeStop() }, end: plan.end)
    }
}
