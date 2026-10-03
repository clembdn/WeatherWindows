import SwiftUI

/// Day planning arrives in Part 3; until then the tab explains what comes next.
struct PlanView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Planning Comes Next",
                systemImage: "map",
                description: Text("Add your errands first. Planning a dry day arrives in the next version.")
            )
            .navigationTitle("Plan")
        }
    }
}
