import Charts
import SolverKit
import SwiftUI

// Time against rain for every plan of the frontier; touch the chart to select the closest plan.
struct TradeOffChart: View {
    let schedules: [ScoredSchedule]
    @Binding var selectedID: String?
    @State private var touchedMinutes: Double?

    var body: some View {
        Chart(schedules) { schedule in
            let isSelected = schedule.id == selectedID
            PointMark(
                x: .value("Minutes until back", schedule.duration / 60),
                y: .value("Rain, worst case", schedule.robustExposure)
            )
            .symbol(isSelected ? BasicChartSymbolShape.diamond : .circle)
            .symbolSize(isSelected ? 260 : 90)
            .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
            .annotation(position: .top, spacing: 6) {
                if isSelected {
                    Text("Leave \(Melbourne.time(schedule.departure))")
                        .font(.caption.bold())
                }
            }
            .accessibilityLabel("Leave \(Melbourne.time(schedule.departure))")
            .accessibilityValue("Back \(Melbourne.time(schedule.returnTime)), \(PlanText.rain(schedule.robustExposure))")
        }
        .chartXSelection(value: $touchedMinutes)
        .onChange(of: touchedMinutes) {
            // The value goes back to nil when the finger lifts, so only a real touch changes the selection.
            guard let minutes = touchedMinutes else { return }
            let closest = schedules.min { abs($0.duration / 60 - minutes) < abs($1.duration / 60 - minutes) }
            selectedID = closest?.id
        }
        .chartXAxisLabel("Minutes until you're back")
        .chartYAxisLabel("Rain, worst case (min)")
        .frame(minHeight: 220)
    }
}
