import SwiftUI
import UIKit

// Dry or rainy, with an icon and words as well as colour.
struct RainBadge: View {
    let exposure: Double

    var body: some View {
        let isDry = PlanText.isDry(exposure)
        Label(PlanText.rain(exposure), systemImage: isDry ? "sun.max" : "cloud.rain.fill")
            .font(.subheadline.weight(isDry ? .regular : .semibold))
            .foregroundStyle(isDry ? Color.secondary : Color.blue)
    }
}

// Reminds the user how coarse the hourly forecast is.
struct ForecastNotice: View {
    var body: some View {
        Label("Rain comes from the hourly forecast at the centre of your errands. "
                + "Scores assume it may arrive up to 30 minutes early or late.",
              systemImage: "info.circle")
            .font(.footnote)
            .foregroundStyle(.secondary)
    }
}

// An error message with a Retry button.
struct ErrorRow: View {
    let error: ServiceError
    let retry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(error.errorDescription ?? "Something went wrong.", systemImage: "exclamationmark.triangle")
            Button("Retry", action: retry)
                .buttonStyle(.bordered)
        }
    }
}

// A field's error under it: icon and text, never colour alone.
struct ValidationMessage: View {
    let text: String?

    var body: some View {
        if let text {
            Label(text, systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
        }
    }
}

// A chosen place, or a grey hint asking the user to choose one.
struct PlaceLabel: View {
    let place: Place?
    let placeholder: String

    var body: some View {
        if let place {
            Label(place.name, systemImage: "mappin.and.ellipse")
        } else {
            Text(placeholder)
                .foregroundStyle(.secondary)
        }
    }
}

// Shown when the user refused notifications.
struct NotificationSettingsButton: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        Button("Turn On Notifications in Settings", systemImage: "gear") {
            if let url = URL(string: UIApplication.openSettingsURLString) {
                openURL(url)
            }
        }
    }
}

// Always visible in replay mode, so recorded rain is never mistaken for today's weather.
struct ReplayBanner: View {
    private var label: String {
        let style = Date.FormatStyle(timeZone: Melbourne.timeZone).day().month(.abbreviated).hour().minute()
        return "Replay · " + ReplayData.now.formatted(style)
    }

    var body: some View {
        Label(label, systemImage: "clock.arrow.circlepath")
            .font(.footnote.weight(.semibold))
            .dynamicTypeSize(...DynamicTypeSize.accessibility1)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(Color.orange.opacity(0.25))
            .accessibilityLabel("Replay mode: recorded weather from \(label)")
    }
}
