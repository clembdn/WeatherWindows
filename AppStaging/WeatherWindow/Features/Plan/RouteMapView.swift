import MapKit
import SolverKit
import SwiftUI
import WeatherWindowCore

// The chosen plan on a map: dry stretches solid and blue, rainy stretches dashed and orange, stops numbered.
struct RouteMapView: View {
    let result: PlanResult
    let schedule: ScoredSchedule

    // One line per walk, straight until Apple Maps sends the real path.
    @State private var lines: [[GeoPoint]] = []

    var body: some View {
        let segments = rainSegments()
        let rainyCount = segments.filter(\.isRainy).count

        VStack(alignment: .leading, spacing: 8) {
            Map {
                ForEach(segments.indices, id: \.self) { index in
                    let segment = segments[index]
                    MapPolyline(coordinates: segment.points.map(\.coordinate))
                        .stroke(segment.isRainy ? Color.orange : Color.blue,
                                style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round,
                                                   dash: segment.isRainy ? [2, 10] : []))
                }
                Marker(result.start.name, systemImage: "figure.walk", coordinate: result.start.location.coordinate)
                ForEach(schedule.order.indices, id: \.self) { index in
                    let stop = schedule.order[index]
                    Marker(stop.name, monogram: Text("\(index + 1)"), coordinate: stop.location.coordinate)
                }
            }
            .mapStyle(.standard(pointsOfInterest: .excludingAll))
            .frame(height: 260)
            .accessibilityLabel("Map of the route, with \(rainyCount) rainy stretches")

            HStack(spacing: 16) {
                Label("Dry: solid", systemImage: "line.diagonal")
                Label("Rain: dashed", systemImage: "cloud.rain")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .task(id: schedule.id) {
            lines = []
            var newLines: [[GeoPoint]] = []
            for leg in schedule.legs {
                newLines.append(await result.data.routeLine(from: result.location(of: leg.from), to: result.location(of: leg.to)))
            }
            lines = newLines
        }
    }

    // Each walk is cut where it goes from dry to rainy: a minute is rainy if any scenario has rain there.
    private func rainSegments() -> [RouteGeometry.Segment] {
        var segments: [RouteGeometry.Segment] = []
        for (index, leg) in schedule.legs.enumerated() {
            let from = result.location(of: leg.from)
            let to = result.location(of: leg.to)
            let line = index < lines.count ? lines[index] : [from, to]
            let samples = LegSampler.samples(from: from, to: to, departure: leg.departure,
                                             duration: leg.arrival.timeIntervalSince(leg.departure))
            var rainyMinutes: [Bool] = []
            for sample in samples {
                rainyMinutes.append(result.scenarios.contains { $0.weight(at: sample.point, time: sample.time) >= 0.1 })
            }
            segments += RouteGeometry.segments(of: line, rainyMinutes: rainyMinutes)
        }
        return segments
    }
}
