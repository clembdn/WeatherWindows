import Foundation
import WeatherWindowCore

/// The Open-Meteo ensemble: the same forecast run many times from slightly different starting conditions.
public struct OpenMeteoEnsembleResponse: Decodable, Sendable {
    public let times: [Date]
    /// Hourly precipitation (mm) of each run; the keys are `precipitation`, `precipitation_member01`…
    public let members: [[Double]]

    // The member keys are only known once the JSON is read, so the keys are plain strings.
    private struct JSONKey: CodingKey {
        var stringValue: String
        var intValue: Int? { nil }

        init(_ stringValue: String) {
            self.stringValue = stringValue
        }

        init?(stringValue: String) {
            self.stringValue = stringValue
        }

        init?(intValue: Int) {
            nil
        }
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: JSONKey.self)
        let hourly = try container.nestedContainer(keyedBy: JSONKey.self, forKey: JSONKey("hourly"))
        let seconds = try hourly.decode([TimeInterval].self, forKey: JSONKey("time"))

        var members: [[Double]] = []
        let keys = hourly.allKeys.filter { $0.stringValue.hasPrefix("precipitation") }.sorted { $0.stringValue < $1.stringValue }
        for key in keys {
            let values = try hourly.decode([Double?].self, forKey: key)
            guard values.count == seconds.count else {
                throw DecodingError.dataCorrupted(DecodingError.Context(
                    codingPath: hourly.codingPath + [key],
                    debugDescription: "An ensemble member does not have one value per hour."
                ))
            }
            members.append(values.map { $0 ?? 0 })
        }
        if members.isEmpty {
            throw DecodingError.dataCorrupted(DecodingError.Context(
                codingPath: hourly.codingPath,
                debugDescription: "The ensemble has no precipitation member."
            ))
        }

        times = seconds.map { Date(timeIntervalSince1970: $0) }
        self.members = members
    }

    /// Five runs as rain fields, chosen from the driest to the wettest between `start` and `end`
    /// (10th, 30th, 50th, 70th and 90th percentiles). The median run comes first, as "the forecast as is".
    public func scenarios(from start: Date, to end: Date) -> [HourlyRainField] {
        var totals: [(member: Int, rain: Double)] = []
        for (member, values) in members.enumerated() {
            var rain = 0.0
            for (hour, time) in times.enumerated() where time > start && time <= end.addingTimeInterval(3600) {
                rain += values[hour]
            }
            totals.append((member, rain))
        }
        totals.sort { $0.rain < $1.rain }

        var fields: [HourlyRainField] = []
        for percentile in [0.5, 0.1, 0.3, 0.7, 0.9] {
            let member = totals[Int((Double(totals.count - 1) * percentile).rounded())].member
            var samples: [WeatherSample] = []
            for (hour, time) in times.enumerated() {
                // One run either rains or not: the weight comes from the amount alone.
                samples.append(WeatherSample(time: time, precipitationProbability: 100, precipitation: members[member][hour]))
            }
            fields.append(HourlyRainField(samples: samples))
        }
        return fields
    }
}
