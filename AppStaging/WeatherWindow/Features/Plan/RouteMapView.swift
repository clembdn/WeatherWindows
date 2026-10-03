import MapKit
import SolverKit
import SwiftUI
import WeatherWindowCore

/// The chosen plan on a map: dry stretches solid, rainy stretches dashed and orange, stops numbered.
struct RouteMapView: View {
    let result: PlanResult
    let schedule: ScoredSchedule

    @State private var lines: [Int: [GeoPoint]] = [:]

    /// A minute counts as rainy from this weight on, in any scenario.
    static let rainyMinuteWeight = 0.1

    private struct StyledSegment: Identifiable {
        let id: Int
        let segment: RouteGeometry.Segment
    }

    private var segments: [StyledSegment] {
        var styled: [StyledSegment] = []
        for (index, leg) in schedule.legs.enumerated() {
            let ends = endpoints(of: leg)
            let line = lines[index] ?? [ends.from, ends.to]
            let samples = LegSampler.samples(from: ends.from, to: ends.to, departure: leg.departure,
                                             duration: leg.arrival.timeIntervalSince(leg.departure))
            let rainy = samples.map { sample in
                result.scenarios.contains { $0.weight(at: sample.point, time: sample.time) >= Self.rainyMinuteWeight }
            }
            for segment in RouteGeometry.segments(of: line, rainyMinutes: rainy) {
                styled.append(StyledSegment(id: styled.count, segment: segment))
            }
        }
        return styled
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Map {
                ForEach(segments) { styled in
                    MapPolyline(coordinates: styled.segment.points.map(\.coordinate))
                        .stroke(styled.segment.isRainy ? Color.orange : Color.blue,
                                style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round,
                                                   dash: styled.segment.isRainy ? [2, 10] : []))
                }
                Marker(result.start.name, systemImage: "figure.walk", coordinate: result.start.location.coordinate)
                ForEach(Array(schedule.order.enumerated()), id: \.offset) { index, stop in
                    Marker(stop.name, monogram: Text("\(index + 1)"), coordinate: stop.location.coordinate)
                }
            }
            .mapStyle(.standard(pointsOfInterest: .excludingAll))
            .frame(height: 260)
            .accessibilityLabel("Map of the route, with \(segments.count { $0.segment.isRainy }) rainy stretches")

            HStack(spacing: 16) {
                Label("Dry: solid", systemImage: "line.diagonal")
                Label("Rain: dashed", systemImage: "cloud.rain")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .task(id: schedule.id) {
            for (index, leg) in schedule.legs.enumerated() {
                let ends = endpoints(of: leg)
                lines[index] = await result.routeLine(ends.from, ends.to)
            }
        }
    }

    private func endpoints(of leg: Leg) -> (from: GeoPoint, to: GeoPoint) {
        (location(of: leg.from), location(of: leg.to))
    }

    private func location(of node: Node) -> GeoPoint {
        switch node {
        case .start: result.start.location
        case .end: result.end.location
        case .stop(let id): result.stops.first { $0.id == id }?.location ?? result.start.location
        }
    }
}
