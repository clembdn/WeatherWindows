//
//  RouteMapView.swift
//  WeatherWindow
//
//  Created by Clement Boudon on 7/10/2026.
//

import MapKit
import SwiftUI

struct RouteMapView: View {
    let result: PlanResult
    let schedule: Schedule

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
            for walk in schedule.walks {
                newLines.append(await result.data.routeLine(from: result.location(of: walk.from), to: result.location(of: walk.to)))
            }
            lines = newLines
        }
    }

    private func rainSegments() -> [RouteSplitter.Segment] {
        var segments: [RouteSplitter.Segment] = []
        for (index, walk) in schedule.walks.enumerated() {
            let from = result.location(of: walk.from)
            let to = result.location(of: walk.to)
            let line = index < lines.count ? lines[index] : [from, to]
            let minutes = WalkRain.minutes(from: from, to: to, departure: walk.departure,
                                           duration: walk.arrival.timeIntervalSince(walk.departure))
            var rainyMinutes: [Bool] = []
            for minute in minutes {
                rainyMinutes.append(result.scenarios.contains { $0.weight(at: minute.point, time: minute.time) >= 0.1 })
            }
            segments += RouteSplitter.segments(of: line, rainyMinutes: rainyMinutes)
        }
        return segments
    }
}
