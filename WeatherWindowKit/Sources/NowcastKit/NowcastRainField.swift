import Foundation
import WeatherWindowCore

/// Rain weight from extrapolated radar, fading into the hourly forecast as the lead time grows.
public struct NowcastRainField: RainField {
    /// Extrapolated frames, one per minute after the last radar image.
    public let frames: [RadarFrame]
    /// When the last real radar image was captured: lead time is measured from it, not from "now".
    public let lastObservation: Date
    public let fallback: any RainField
    public let georeference: Georeference
    public let horizon: TimeInterval

    public init(frames: [RadarFrame], lastObservation: Date, fallback: any RainField,
                georeference: Georeference = Georeference(), horizon: TimeInterval = 30 * 60) {
        self.frames = frames.sorted { $0.time < $1.time }
        self.lastObservation = lastObservation
        self.fallback = fallback
        self.georeference = georeference
        self.horizon = horizon
    }

    /// Weight of the nowcast in the blend: 1 at the last image, 0 from the horizon on.
    public func nowcastShare(at time: Date) -> Double {
        max(0, 1 - max(0, time.timeIntervalSince(lastObservation)) / horizon)
    }

    public func weight(at point: GeoPoint, time: Date) -> Double {
        let share = nowcastShare(at: time)
        guard share > 0, let frame = closestFrame(to: time) else {
            return fallback.weight(at: point, time: time)
        }
        let pixel = georeference.pixel(for: point)
        let radarWeight = ReflectivityConverter.rainWeight(dBZ: Double(frame.grid.sample(x: pixel.x, y: pixel.y)))
        return share * radarWeight + (1 - share) * fallback.weight(at: point, time: time)
    }

    private func closestFrame(to time: Date) -> RadarFrame? {
        frames.min { abs($0.time.timeIntervalSince(time)) < abs($1.time.timeIntervalSince(time)) }
    }
}
