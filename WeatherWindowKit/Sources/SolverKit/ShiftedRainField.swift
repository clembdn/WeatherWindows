import Foundation
import WeatherWindowCore

/// A rain field moved in time by a fixed offset, used to build robustness scenarios.
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

    /// The forecast as is, then 30 and 15 minutes early, then 15 and 30 minutes late.
    public static func scenarios(around base: any RainField) -> [any RainField] {
        [
            base,
            ShiftedRainField(base: base, offset: -30 * 60),
            ShiftedRainField(base: base, offset: -15 * 60),
            ShiftedRainField(base: base, offset: 15 * 60),
            ShiftedRainField(base: base, offset: 30 * 60)
        ]
    }
}
