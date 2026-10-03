import SwiftUI

/// The three main sections, each with its own navigation stack.
struct RootView: View {
    var body: some View {
        TabView {
            Tab("Plan", systemImage: "map") {
                DayPlanView()
            }
            Tab("Errands", systemImage: "checklist") {
                ErrandListView()
            }
            Tab("About", systemImage: "info.circle") {
                AboutView()
            }
        }
    }
}
