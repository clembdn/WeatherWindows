import Charts
import SolverKit
import SwiftUI

/// Time against rain for every plan on the frontier; tap a point to select it.
struct TradeOffChart: View {
    let schedules: [ScoredSchedule]
    @Binding var selectedID: String?

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
                    Text("Leave \(AppClock.time(schedule.departure))")
                        .font(.caption.bold())
                }
            }
            .accessibilityLabel("Leave \(AppClock.time(schedule.departure))")
            .accessibilityValue("Back \(AppClock.time(schedule.returnTime)), \(PlanText.rain(schedule.robustExposure))")
        }
        .chartXAxisLabel("Minutes until you're back")
        .chartYAxisLabel("Rain, worst case (min)")
        .chartOverlay { proxy in
            GeometryReader { geometry in
                Rectangle()
                    .fill(.clear)
                    .contentShape(Rectangle())
                    .onTapGesture { location in
                        select(near: location, proxy: proxy, geometry: geometry)
                    }
            }
        }
        .frame(minHeight: 220)
    }

    /// Picks the plan whose point is closest to the finger on screen (2D distance).
    private func select(near location: CGPoint, proxy: ChartProxy, geometry: GeometryProxy) {
        guard let plotFrame = proxy.plotFrame else { return }
        let origin = geometry[plotFrame].origin
        let tap = CGPoint(x: location.x - origin.x, y: location.y - origin.y)

        selectedID = schedules.min { first, second in
            distance(of: first, to: tap, proxy: proxy) < distance(of: second, to: tap, proxy: proxy)
        }?.id
    }

    private func distance(of schedule: ScoredSchedule, to tap: CGPoint, proxy: ChartProxy) -> CGFloat {
        guard let point = proxy.position(forX: schedule.duration / 60, y: schedule.robustExposure) else {
            return .infinity
        }
        return hypot(point.x - tap.x, point.y - tap.y)
    }
}
