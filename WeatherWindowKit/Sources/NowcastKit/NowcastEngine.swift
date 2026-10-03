import Foundation
import WeatherWindowCore

/// A ready nowcast: the images it used, the motion it measured, and the 30 extrapolated minutes.
public struct Nowcast: Sendable {
    public let observed: [RadarFrame]
    public let forecast: [RadarFrame]
    public let motion: MotionField
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
}

/// Turns recent radar frames into a nowcast around the places of a route.
public enum NowcastEngine {
    /// Older than this, the radar no longer says anything useful about the next 30 minutes.
    public static let maximumAge: TimeInterval = 30 * 60
    /// Extra pixels around the route: how far rain can travel in 30 minutes (≈ 35 km).
    public static let margin = 73

    public static func make(frames: [RadarFrame], around points: [GeoPoint], now: Date, fallback: any RainField,
                            estimator: BlockMatchingEstimator = BlockMatchingEstimator(),
                            georeference: Georeference = Georeference()) -> NowcastOutcome {
        let sorted = frames.sorted { $0.time < $1.time }
        guard let last = sorted.last else { return .noFrames }
        guard now.timeIntervalSince(last.time) <= maximumAge else { return .stale(lastObservation: last.time) }

        let region = PixelRegion.around(points.map(georeference.pixel(for:)), margin: margin, size: last.grid.size)
        let motion = estimator.estimate(from: sorted, region: region)
        let forecast = Advector.forecast(from: last, motion: motion, minutes: 1...30, region: region)
        let field = NowcastRainField(frames: [last] + forecast, lastObservation: last.time,
                                     fallback: fallback, georeference: georeference)
        return .ready(Nowcast(observed: sorted, forecast: forecast, motion: motion, region: region, field: field))
    }
}
