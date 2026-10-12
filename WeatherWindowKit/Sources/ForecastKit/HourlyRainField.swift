import Foundation
import WeatherWindowCore

/// Rain weight from the hourly forecast at one point (the centre of the errands); position is ignored.
public struct HourlyRainField: RainField {
    public let samples: [WeatherSample]

    public init(samples: [WeatherSample]) {
        self.samples = samples.sorted { $0.time < $1.time }
    }

    /// The weight of the forecast hour covering `time`; outside the forecast the weight is 0.
    public func weight(at point: GeoPoint, time: Date) -> Double {
        // Open-Meteo gives at time T the rain of the hour before T, so we look for the first T after `time`.
        let sample = samples.first { $0.time > time }
        guard let sample, sample.time.timeIntervalSince(time) <= 3600 else { return 0 }
        return sample.rainWeight
    }
}
