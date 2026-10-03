import Foundation
import WeatherWindowCore

/// A rain field whose timing is moved by a fixed offset, used to build robustness scenarios.
public struct ShiftedRainField: RainField {
    public let base: any RainField
    public let offset: TimeInterval

    /// A positive offset makes the rain arrive later than the base field predicts.
    public init(base: any RainField, offset: TimeInterval) {
        self.base = base
        self.offset = offset
    }

    public func weight(at point: GeoPoint, time: Date) -> Double {
        base.weight(at: point, time: time.addingTimeInterval(-offset))
    }
}
