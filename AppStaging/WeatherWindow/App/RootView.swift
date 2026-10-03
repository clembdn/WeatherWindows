import SwiftUI

/// The three main sections, each with its own navigation stack.
struct RootView: View {
    @AppStorage(AppMode.replayKey) private var replaySetting = false

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
        .safeAreaInset(edge: .top, spacing: 0) {
            if AppMode.isReplay(setting: replaySetting) {
                ReplayBanner()
            }
        }
    }
}

/// Always visible in replay, so recorded rain is never mistaken for today's weather.
struct ReplayBanner: View {
    var body: some View {
        Label(ReplaySession.label, systemImage: "clock.arrow.circlepath")
            .font(.footnote.weight(.semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(Color.orange.opacity(0.25))
            .accessibilityLabel("Replay mode: recorded weather from \(ReplaySession.label)")
    }
}
