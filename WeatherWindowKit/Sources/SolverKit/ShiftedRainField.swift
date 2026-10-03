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

    /// Offsets of the robustness scenarios besides the forecast itself.
    public static let robustnessOffsets: [TimeInterval] = [-30, -15, 15, 30].map { $0 * 60 }

    /// The forecast as is, then the same forecast 30 and 15 minutes early, 15 and 30 minutes late.
    public static func scenarios(around base: any RainField) -> [any RainField] {
        [base] + robustnessOffsets.map { ShiftedRainField(base: base, offset: $0) }
    }
}
