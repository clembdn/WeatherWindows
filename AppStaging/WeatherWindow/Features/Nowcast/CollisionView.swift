import NowcastKit
import SolverKit
import SwiftUI
import UIKit
import WeatherWindowCore

/// Rain observed or predicted at the scrubber's time, your route and where you will be then.
struct CollisionView: View {
    let result: NextWalkResult
    let nowcast: Nowcast
    let minuteOffset: Double

    private var georeference: Georeference { nowcast.field.georeference }
    private var time: Date { result.now.addingTimeInterval(minuteOffset * 60) }

    /// The frame shown: the closest observed image in the past, the extrapolated one in the future.
    private var frame: (grid: RainGrid, isPredicted: Bool, opacity: Double) {
        if time <= nowcast.lastObservation {
            let observed = nowcast.observed.min {
                abs($0.time.timeIntervalSince(time)) < abs($1.time.timeIntervalSince(time))
            }
            return (observed?.grid ?? .empty(size: 512), false, 1)
        }
        let lead = time.timeIntervalSince(nowcast.lastObservation)
        let index = min(max(Int((lead / 60).rounded()) - 1, 0), nowcast.forecast.count - 1)
        return (nowcast.forecast[index].grid, true, max(0.45, 1 - lead / (60 * 60)))
    }

    var body: some View {
        let shown = frame
        let region = nowcast.region
        let image = RadarColor.image(of: shown.grid, region: region, opacity: shown.opacity)
        let route = routePoints
        let position = position(at: time)

        Canvas { context, size in
            let scaleX = size.width / Double(region.maxX - region.minX + 1)
            let scaleY = size.height / Double(region.maxY - region.minY + 1)
            func place(_ point: GeoPoint) -> CGPoint {
                let pixel = georeference.pixel(for: point)
                return CGPoint(x: (pixel.x - Double(region.minX)) * scaleX, y: (pixel.y - Double(region.minY)) * scaleY)
            }

            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(uiColor: .secondarySystemBackground)))
            if let image {
                context.draw(Image(decorative: image, scale: 1).interpolation(.none), in: CGRect(origin: .zero, size: size))
            }

            var path = Path()
            if let first = route.first {
                path.move(to: place(first))
                route.dropFirst().forEach { path.addLine(to: place($0)) }
            }
            context.stroke(path, with: .color(.primary), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
            for point in route {
                let centre = place(point)
                context.fill(Path(ellipseIn: CGRect(x: centre.x - 4, y: centre.y - 4, width: 8, height: 8)), with: .color(.primary))
            }

            let you = place(position)
            context.fill(Path(ellipseIn: CGRect(x: you.x - 9, y: you.y - 9, width: 18, height: 18)), with: .color(.white))
            context.fill(Path(ellipseIn: CGRect(x: you.x - 6, y: you.y - 6, width: 12, height: 12)), with: .color(.orange))
        }
        .aspectRatio(Double(region.maxX - region.minX + 1) / Double(region.maxY - region.minY + 1), contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(alignment: .topLeading) {
            Text(AppClock.time(time) + (shown.isPredicted ? " · predicted" : " · observed"))
                .font(.caption.weight(.semibold))
                .padding(6)
                .background(.regularMaterial, in: Capsule())
                .padding(8)
        }
        .overlay(alignment: .bottomTrailing) {
            Text("Radar: RainViewer")
                .font(.caption2)
                .padding(4)
                .background(.regularMaterial, in: Capsule())
                .padding(6)
        }
        .accessibilityElement()
        .accessibilityLabel("Rain map")
        .accessibilityValue(accessibilityValue(grid: shown.grid, position: position, isPredicted: shown.isPredicted))
    }

    private var routePoints: [GeoPoint] {
        guard let schedule = result.recommended else { return [result.input.current.location] }
        return [result.input.current.location] + schedule.order.map(\.location) + [result.input.end.location]
    }

    /// Where you are at `time`, following the recommended schedule's first walk.
    private func position(at time: Date) -> GeoPoint {
        let start = result.input.current.location
        guard let schedule = result.recommended, let leg = schedule.legs.first else { return start }
        let destination = schedule.order.first?.location ?? result.input.end.location
        guard time > leg.departure else { return start }
        guard time < leg.arrival else { return destination }
        let progress = time.timeIntervalSince(leg.departure) / leg.arrival.timeIntervalSince(leg.departure)
        return GeoPoint(
            latitude: start.latitude + (destination.latitude - start.latitude) * progress,
            longitude: start.longitude + (destination.longitude - start.longitude) * progress
        )
    }

    private func accessibilityValue(grid: RainGrid, position: GeoPoint, isPredicted: Bool) -> String {
        let pixel = georeference.pixel(for: position)
        let rain = RadarColor.description(dBZ: grid.sample(x: pixel.x, y: pixel.y))
        return "\(AppClock.time(time)), \(isPredicted ? "predicted" : "observed"), \(rain) at your position"
    }
}
