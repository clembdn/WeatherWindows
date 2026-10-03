import SolverKit
import SwiftUI

/// "Leave now" or "Wait 20 min", with the rain each choice means and a reminder button.
struct DepartureAdviceCard: View {
    let result: NextWalkResult
    let reminderMessage: String?
    let remind: (Date) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let reason = result.advice.infeasibility {
                Label("Nothing Fits Any More", systemImage: "clock.badge.xmark")
                    .font(.headline)
                Text(PlanText.reason(reason))
            } else if let later = result.advice.bestLater {
                Label("Wait \(PlanText.duration(result.advice.waitingTime(from: result.now)))", systemImage: "hourglass")
                    .font(.title2.bold())
                choice("Leave at \(AppClock.time(later.departure))", schedule: later)
                if let now = result.advice.leaveNow {
                    choice("Leave now", schedule: now)
                }
                Button("Remind Me at \(AppClock.time(later.departure))", systemImage: "bell") {
                    remind(later.departure)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("remind-me")
            } else if let now = result.advice.leaveNow {
                Label("Leave Now", systemImage: "figure.walk.departure")
                    .font(.title2.bold())
                choice("Leave now", schedule: now)
                Text(PlanText.isDry(now.robustExposure)
                     ? "No rain expected on your walks in the next 30 minutes."
                     : "Waiting up to 30 minutes would not keep you drier.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let reminderMessage {
                Text(reminderMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func choice(_ title: String, schedule: ScoredSchedule) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.headline)
            if let leg = schedule.legs.first {
                Text("Next: walk \(PlanText.duration(leg.arrival.timeIntervalSince(leg.departure))) to \(result.name(of: leg.to))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                RainBadge(exposure: leg.exposureByScenario.max() ?? 0)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
