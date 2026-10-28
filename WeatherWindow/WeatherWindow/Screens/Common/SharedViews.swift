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
            .foregroundStyle(isDry ? Color.secondaryText : Color.accentColor)
    }
}

struct ConfidenceBadge: View {
    let level: Int

    private var icon: String {
        switch level {
        case 3:
            "gauge.with.dots.needle.67percent"
        case 2:
            "gauge.with.dots.needle.50percent"
        default:
            "gauge.with.dots.needle.33percent"
        }
    }

    var body: some View {
        Label(PlanText.confidence(level), systemImage: icon)
            .font(.subheadline)
            .foregroundStyle(.secondaryText)
    }
}

struct ForecastNotice: View {
    let usesEnsemble: Bool

    private var text: String {
        let confidence = " Confidence is 3 when the scenarios agree within 2 min of rain, and 1 when they differ by 5 min or more."
        if usesEnsemble {
            return "Rain comes from the 40 runs of the ensemble forecast at the centre of your errands. "
                + "Scores keep the worst of five runs, from the driest to the wettest." + confidence
        }
        return "Rain comes from the hourly forecast at the centre of your errands. "
            + "Scores assume it may arrive up to 30 minutes early or late." + confidence
    }

    var body: some View {
        Label(text + " Weather: Open-Meteo (CC BY 4.0).", systemImage: "info.circle")
            .font(.footnote)
            .foregroundStyle(.secondaryText)
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
                .foregroundStyle(.errorRed)
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
                .foregroundStyle(.secondaryText)
        }
    }
}

struct NotificationSettingsButton: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        Button("Turn On Notifications in Settings", systemImage: "gear") {
            if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                openURL(url)
            }
        }
    }
}

struct ReplayBanner: View {
    private var label: String {
        let style = Date.FormatStyle(timeZone: Melbourne.timeZone).day().month(.abbreviated).year().hour().minute()
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
