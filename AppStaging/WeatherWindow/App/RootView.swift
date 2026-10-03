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

extension View {
    /// Shows the replay banner under the navigation bar of a screen, when replay is on.
    func replayBanner() -> some View {
        modifier(ReplayBannerModifier())
    }
}

private struct ReplayBannerModifier: ViewModifier {
    @AppStorage(AppMode.replayKey) private var replaySetting = false

    func body(content: Content) -> some View {
        content.safeAreaInset(edge: .top, spacing: 0) {
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
            .dynamicTypeSize(...DynamicTypeSize.accessibility1)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(Color.orange.opacity(0.25))
            .accessibilityLabel("Replay mode: recorded weather from \(ReplaySession.label)")
    }
}
