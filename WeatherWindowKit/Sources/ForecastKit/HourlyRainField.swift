import Foundation
import WeatherWindowCore

/// Rain weight from the hourly forecast at one point (the centroid of the errands); position is ignored.
public struct HourlyRainField: RainField {
    public let samples: [WeatherSample]

    public init(samples: [WeatherSample]) {
        self.samples = samples.sorted { $0.time < $1.time }
    }

    /// The weight of the forecast hour covering `time`: the sample at T covers [T − 1 h, T).
    /// Outside the forecast the weight is 0.
    public func weight(at point: GeoPoint, time: Date) -> Double {
        var low = 0
        var high = samples.count
        while low < high {
            let middle = (low + high) / 2
            if samples[middle].time <= time { low = middle + 1 } else { high = middle }
        }
        guard low < samples.count, samples[low].time.timeIntervalSince(time) <= 3600 else { return 0 }
        return samples[low].rainWeight
    }
}
