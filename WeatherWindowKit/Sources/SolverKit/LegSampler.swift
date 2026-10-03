import Foundation
import WeatherWindowCore

/// One point of a walk: where you are in the middle of a minute, and how much of a minute it covers.
public struct LegSample: Hashable, Sendable {
    public let point: GeoPoint
    public let time: Date
    public let minutes: Double
}

/// Cuts a walk into one sample per minute along the straight line from A to B.
public enum LegSampler {
    public static func samples(from origin: GeoPoint, to destination: GeoPoint,
                               departure: Date, duration: TimeInterval) -> [LegSample] {
        guard duration > 0 else { return [] }
        let minuteCount = Int((duration / 60).rounded(.up))

        return (0..<minuteCount).map { minute in
            let start = Double(minute) * 60
            let end = min(start + 60, duration)
            let middle = (start + end) / 2
            let progress = middle / duration
            let point = GeoPoint(
                latitude: origin.latitude + (destination.latitude - origin.latitude) * progress,
                longitude: origin.longitude + (destination.longitude - origin.longitude) * progress
            )
            return LegSample(point: point, time: departure.addingTimeInterval(middle), minutes: (end - start) / 60)
        }
    }

    /// Rain weight × minutes crossed along the samples.
    public static func exposure(of samples: [LegSample], in field: any RainField) -> Double {
        samples.reduce(0) { $0 + field.weight(at: $1.point, time: $1.time) * $1.minutes }
    }
}
