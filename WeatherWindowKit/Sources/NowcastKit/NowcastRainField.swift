import Foundation
import WeatherWindowCore

/// Rain weight from extrapolated radar, fading into the hourly forecast as the lead time grows.
public struct NowcastRainField: RainField {
    /// After this lead time only the hourly forecast is used.
    public static let horizon: TimeInterval = 30 * 60

    /// The last radar image, then one extrapolated frame per minute.
    public let frames: [RadarFrame]
    /// When the last real radar image was captured: lead time is measured from it, not from "now".
    public let lastObservation: Date
    public let fallback: any RainField
    public let georeference = Georeference()

    public init(frames: [RadarFrame], lastObservation: Date, fallback: any RainField) {
        self.frames = frames
        self.lastObservation = lastObservation
        self.fallback = fallback
    }

    public func weight(at point: GeoPoint, time: Date) -> Double {
        let forecastWeight = fallback.weight(at: point, time: time)
        // 1 at the last image, 0 at the horizon: w = share × radar + (1 − share) × forecast.
        let lead = max(0, time.timeIntervalSince(lastObservation))
        let share = max(0, 1 - lead / Self.horizon)
        let closest = frames.min { abs($0.time.timeIntervalSince(time)) < abs($1.time.timeIntervalSince(time)) }
        guard share > 0, let frame = closest else { return forecastWeight }

        let pixel = georeference.pixel(for: point)
        let dBZ = Double(frame.grid.sample(x: pixel.x, y: pixel.y))
        return share * ReflectivityConverter.rainWeight(dBZ: dBZ) + (1 - share) * forecastWeight
    }
}
