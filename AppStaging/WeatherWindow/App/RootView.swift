import SwiftUI

// The three main sections, each with its own navigation stack, under the replay banner.
struct RootView: View {
    @AppStorage("replayMode") private var replayMode = false

    var body: some View {
        VStack(spacing: 0) {
            if replayMode {
                ReplayBanner()
            }
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
}
