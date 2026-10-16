//
//  SharedViews.swift
//  WeatherWindow
//
//  Created by Clement Boudon on 12/10/2026.
//

import SwiftUI
import UIKit

struct RainBadge: View {
    let exposure: Double

    var body: some View {
        let isDry = PlanText.isDry(exposure)
        Label(PlanText.rain(exposure), systemImage: isDry ? "sun.max" : "cloud.rain.fill")
            .font(.subheadline.weight(isDry ? .regular : .semibold))
            .foregroundStyle(isDry ? Color.secondary : Color.blue)
    }
}

struct ForecastNotice: View {
    let usesEnsemble: Bool

    private var text: String {
        if usesEnsemble {
            return "Rain comes from the 40 runs of the ensemble forecast at the centre of your errands. "
                + "Scores keep the worst of five runs, from the driest to the wettest."
        }
        return "Rain comes from the hourly forecast at the centre of your errands. "
            + "Scores assume it may arrive up to 30 minutes early or late."
    }

    var body: some View {
        Label(text, systemImage: "info.circle")
            .font(.footnote)
            .foregroundStyle(.secondary)
    }
}

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

struct ValidationMessage: View {
    let text: String?

    var body: some View {
        if let text {
            Label(text, systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
        }
    }
}

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
