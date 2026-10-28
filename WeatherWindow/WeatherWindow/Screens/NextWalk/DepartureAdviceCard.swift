//
//  DepartureAdviceCard.swift
//  WeatherWindow
//
//  Created by Clement Boudon on 7/10/2026.
//

import SwiftUI

struct DepartureAdviceCard: View {
    let result: NextWalkResult
    let reminderMessage: String?
    let remind: (Date) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let reason = result.advice.noPlanReason {
                Label("Nothing Fits Any More", systemImage: "clock.badge.xmark")
                    .font(.headline)
                Text(PlanText.reason(reason))
            } else if let later = result.advice.bestLater {
                Label("Wait \(PlanText.duration(result.advice.waitingTime(from: result.now)))", systemImage: "hourglass")
                    .font(.title2.bold())
                choice("Leave at \(Melbourne.time(later.departure))", schedule: later)
                if let now = result.advice.leaveNow {
                    choice("Leave now", schedule: now)
                }
                Button("Remind Me at \(Melbourne.time(later.departure))", systemImage: "bell") {
                    remind(later.departure)
                }
                .buttonStyle(.borderedProminent)
                .tint(.buttonBlue)
            } else if let now = result.advice.leaveNow {
                Label("Leave Now", systemImage: "figure.walk.departure")
                    .font(.title2.bold())
                choice("Leave now", schedule: now)
                Text(PlanText.isDry(now.robustExposure)
                     ? "No rain expected on your walks in the next 30 minutes."
                     : "Waiting up to 30 minutes would not keep you drier.")
                    .font(.footnote)
                    .foregroundStyle(.secondaryText)
            }

            if let reminderMessage {
                Text(reminderMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondaryText)
            }
        }
        // Every line gets its full height: without it, the largest text sizes cut the walk and rain lines to one line.
        .fixedSize(horizontal: false, vertical: true)
        .padding(.vertical, 4)
    }

    private func choice(_ title: String, schedule: Schedule) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.headline)
            if let walk = schedule.walks.first {
                Text("Next: walk \(PlanText.duration(walk.arrival.timeIntervalSince(walk.departure))) to \(result.name(of: walk.to))")
                    .font(.subheadline)
                    .foregroundStyle(.secondaryText)
                RainBadge(exposure: walk.exposureByScenario.max() ?? 0)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
