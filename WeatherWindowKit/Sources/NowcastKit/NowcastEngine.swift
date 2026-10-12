import Foundation
import WeatherWindowCore

/// A ready nowcast: the images it used, the 30 extrapolated minutes, and the area it covers.
public struct Nowcast: Sendable {
    public let observed: [RadarFrame]
    public let forecast: [RadarFrame]
    public let region: PixelRegion
    public let field: NowcastRainField

    public var lastObservation: Date { field.lastObservation }
}

/// What the engine could do with the frames it was given.
public enum NowcastOutcome: Sendable {
    case ready(Nowcast)
    /// The newest image is too old to extrapolate; the hourly forecast must be used alone.
    case stale(lastObservation: Date)
    case noFrames
    /// A place of the route is outside the Melbourne radar tile.
    case outsideRadar
}

/// Turns recent radar frames into a nowcast around the places of a route.
public enum NowcastEngine {
    /// Older than this, the radar no longer says anything useful about the next 30 minutes.
    public static let maximumAge: TimeInterval = 30 * 60
    /// Extra pixels around the route: how far rain can travel in 30 minutes (≈ 35 km).
    public static let margin = 73

    /// Measures the motion, extrapolates 30 minutes and blends the result with the hourly forecast.
    public static func make(frames: [RadarFrame], around points: [GeoPoint], now: Date,
                            fallback: any RainField) -> NowcastOutcome {
        let sorted = frames.sorted { $0.time < $1.time }
        guard let last = sorted.last else { return .noFrames }
        if now.timeIntervalSince(last.time) > maximumAge {
            return .stale(lastObservation: last.time)
        }

        let georeference = Georeference()
        let size = last.grid.size
        var pixels: [(x: Double, y: Double)] = []
        for point in points {
            let pixel = georeference.pixel(for: point)
            if pixel.x < 0 || pixel.y < 0 || pixel.x >= Double(size) || pixel.y >= Double(size) {
                return .outsideRadar
            }
            pixels.append(pixel)
        }

        let region = PixelRegion.around(pixels, margin: margin, size: size)
        let motion = BlockMatchingEstimator().estimate(from: sorted, region: region)
        let forecast = Advector.forecast(from: last, motion: motion, minutes: 1...30, region: region)
        let field = NowcastRainField(frames: [last] + forecast, lastObservation: last.time, fallback: fallback)
        return .ready(Nowcast(observed: sorted, forecast: forecast, region: region, field: field))
    }
}
