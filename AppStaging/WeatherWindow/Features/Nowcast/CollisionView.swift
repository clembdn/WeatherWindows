import NowcastKit
import SolverKit
import SwiftUI
import UIKit
import WeatherWindowCore

// Rain observed or predicted at the slider's time, your route, and where you will be then,
// on an Apple map or as a plain radar grid (which also works offline).
struct CollisionView: View {
    let result: NextWalkResult
    let nowcast: Nowcast
    let minuteOffset: Double
    let showsMap: Bool

    private var time: Date { result.now.addingTimeInterval(minuteOffset * 60) }
    private var isPredicted: Bool { time > nowcast.lastObservation }

    // The closest radar image in the past, or the extrapolated image in the future.
    private var grid: RainGrid {
        if !isPredicted {
            let closest = nowcast.observed.min { abs($0.time.timeIntervalSince(time)) < abs($1.time.timeIntervalSince(time)) }
            return closest?.grid ?? .empty(size: 512)
        }
        let minutesAhead = Int((time.timeIntervalSince(nowcast.lastObservation) / 60).rounded())
        let index = max(0, minutesAhead - 1)
        if index < nowcast.forecast.count {
            return nowcast.forecast[index].grid
        }
        return nowcast.forecast.last?.grid ?? .empty(size: 512)
    }

    // Predicted rain gets paler as it gets less certain.
    private var opacity: Double {
        if !isPredicted {
            return 1
        }
        return max(0.45, 1 - time.timeIntervalSince(nowcast.lastObservation) / 3600)
    }

    private var routePoints: [GeoPoint] {
        guard let schedule = result.recommended else { return [result.input.current.location] }
        return [result.input.current.location] + schedule.order.map(\.location) + [result.input.end.location]
    }

    // Where you are at `time`, following the first walk of the recommended plan.
    private var yourPosition: GeoPoint {
        let start = result.input.current.location
        guard let schedule = result.recommended, let leg = schedule.legs.first else { return start }
        let destination = schedule.order.first?.location ?? result.input.end.location
        if time <= leg.departure {
            return start
        }
        if time >= leg.arrival {
            return destination
        }
        let progress = time.timeIntervalSince(leg.departure) / leg.arrival.timeIntervalSince(leg.departure)
        return GeoPoint(latitude: start.latitude + (destination.latitude - start.latitude) * progress,
                        longitude: start.longitude + (destination.longitude - start.longitude) * progress)
    }

    var body: some View {
        let georeference = nowcast.field.georeference
        // A close-up of about 8 km around the route.
        let region = PixelRegion.around(routePoints.map { georeference.pixel(for: $0) }, margin: 16, size: 512)
        let shownGrid = grid
        let cells = rainCells(of: shownGrid, in: region)
        let route = routePoints.map { point in
            let pixel = georeference.pixel(for: point)
            return CGPoint(x: pixel.x, y: pixel.y)
        }
        let youPixel = georeference.pixel(for: yourPosition)
        let you = CGPoint(x: youPixel.x, y: youPixel.y)
        let background = Color(uiColor: .secondarySystemBackground)

        Group {
            if showsMap {
                RadarMapView(grid: shownGrid, region: region, opacity: opacity, route: routePoints, you: yourPosition)
            } else {
                Canvas { context, size in
                    context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(background))

                    // Everything is drawn in radar pixels, then scaled to the size of the view.
                    let scale = size.width / Double(region.maxX - region.minX + 1)
                    context.scaleBy(x: scale, y: scale)
                    context.translateBy(x: -Double(region.minX), y: -Double(region.minY))

                    for cell in cells {
                        context.fill(Path(CGRect(x: cell.x, y: cell.y, width: 1.05, height: 1.05)), with: .color(cell.color))
                    }

                    var path = Path()
                    path.addLines(route)
                    context.stroke(path, with: .color(.primary),
                                   style: StrokeStyle(lineWidth: 3 / scale, lineCap: .round, lineJoin: .round))
                    for point in route {
                        context.fill(Path(ellipseIn: CGRect(x: point.x - 4 / scale, y: point.y - 4 / scale,
                                                            width: 8 / scale, height: 8 / scale)), with: .color(.primary))
                    }
                    context.fill(Path(ellipseIn: CGRect(x: you.x - 9 / scale, y: you.y - 9 / scale,
                                                        width: 18 / scale, height: 18 / scale)), with: .color(.white))
                    context.fill(Path(ellipseIn: CGRect(x: you.x - 6 / scale, y: you.y - 6 / scale,
                                                        width: 12 / scale, height: 12 / scale)), with: .color(.orange))
                }
                .aspectRatio(Double(region.maxX - region.minX + 1) / Double(region.maxY - region.minY + 1), contentMode: .fit)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(alignment: .topLeading) {
            Text(Melbourne.time(time) + (isPredicted ? " · predicted" : " · observed"))
                .font(.caption.weight(.semibold))
                .padding(6)
                .background(.regularMaterial, in: Capsule())
                .padding(8)
        }
        .overlay(alignment: .topTrailing) {
            // Top corner, so Apple's own map credits at the bottom stay visible.
            Text("Radar: RainViewer")
                .font(.caption2)
                .padding(4)
                .background(.regularMaterial, in: Capsule())
                .padding(6)
        }
        .accessibilityElement()
        .accessibilityLabel("Rain map")
        .accessibilityValue(accessibilityValue(grid: shownGrid, at: youPixel))
    }

    // One coloured square per radar pixel with rain.
    private func rainCells(of grid: RainGrid, in region: PixelRegion) -> [(x: Double, y: Double, color: Color)] {
        let alpha = opacity
        var cells: [(x: Double, y: Double, color: Color)] = []
        for y in region.minY...region.maxY {
            for x in region.minX...region.maxX {
                if let color = RadarColor.color(dBZ: grid[x, y]) {
                    cells.append((Double(x), Double(y), color.opacity(alpha)))
                }
            }
        }
        return cells
    }

    private func accessibilityValue(grid: RainGrid, at pixel: (x: Double, y: Double)) -> String {
        let rain = RadarColor.description(dBZ: grid.sample(x: pixel.x, y: pixel.y))
        return "\(Melbourne.time(time)), \(isPredicted ? "predicted" : "observed"), \(rain) at your position"
    }
}
