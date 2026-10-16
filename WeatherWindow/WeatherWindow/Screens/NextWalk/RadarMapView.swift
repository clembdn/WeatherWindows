//
//  RadarMapView.swift
//  WeatherWindow
//
//  Created by Clement Boudon on 14/10/2026.
//

import MapKit
import SwiftUI

struct RadarMapView: View {
    let grid: RainGrid
    let region: PixelBox
    let opacity: Double
    let route: [GeoPoint]
    let you: GeoPoint

    private struct RainBand {
        let corners: [CLLocationCoordinate2D]
        let color: Color
    }

    var body: some View {
        let bands = rainBands()
        Map(initialPosition: .automatic) {
            ForEach(bands.indices, id: \.self) { index in
                MapPolygon(coordinates: bands[index].corners)
                    .foregroundStyle(bands[index].color.opacity(opacity))
            }
            MapPolyline(coordinates: route.map(\.coordinate))
                .stroke(.primary, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
            Annotation("You", coordinate: you.coordinate) {
                Circle()
                    .fill(.orange)
                    .stroke(.white, lineWidth: 3)
                    .frame(width: 18, height: 18)
            }
        }
        .mapStyle(.standard(pointsOfInterest: .excludingAll))
        .frame(height: 320)
    }

    private func rainBands() -> [RainBand] {
        let pixelConverter = PixelConverter()
        var bands: [RainBand] = []
        for y in region.minY...region.maxY {
            var x = region.minX
            while x <= region.maxX {
                let level = RainColor.level(dBZ: grid[x, y])
                var end = x
                while end + 1 <= region.maxX && RainColor.level(dBZ: grid[end + 1, y]) == level {
                    end += 1
                }
                if let color = RainColor.color(level: level) {
                    let top = Double(y), bottom = Double(y + 1)
                    let left = Double(x), right = Double(end + 1)
                    let corners = [
                        pixelConverter.point(forPixelX: left, y: top),
                        pixelConverter.point(forPixelX: right, y: top),
                        pixelConverter.point(forPixelX: right, y: bottom),
                        pixelConverter.point(forPixelX: left, y: bottom)
                    ]
                    bands.append(RainBand(corners: corners.map(\.coordinate), color: color))
                }
                x = end + 1
            }
        }
        return bands
    }
}
