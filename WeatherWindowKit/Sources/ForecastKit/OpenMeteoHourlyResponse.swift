import Foundation
import WeatherWindowCore

/// One forecast hour. Open-Meteo values describe the hour that ends at `time`.
public struct WeatherSample: Hashable, Sendable {
    public let time: Date
    /// Chance of more than 0.1 mm of rain, in percent.
    public let precipitationProbability: Double
    /// Rain expected during the hour, in millimetres.
    public let precipitation: Double

    public init(time: Date, precipitationProbability: Double, precipitation: Double) {
        self.time = time
        self.precipitationProbability = precipitationProbability
        self.precipitation = precipitation
    }

    public var rainWeight: Double {
        RainWeight.hourly(probability: precipitationProbability, precipitation: precipitation)
    }
}

/// The Open-Meteo hourly forecast, whose parallel arrays are zipped into `WeatherSample`s.
public struct OpenMeteoHourlyResponse: Decodable, Sendable {
    public let location: GeoPoint
    public let samples: [WeatherSample]

    private enum CodingKeys: String, CodingKey {
        case latitude, longitude, hourly
    }

    private enum HourlyKeys: String, CodingKey {
        case time
        case precipitationProbability = "precipitation_probability"
        case precipitation
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        location = GeoPoint(
            latitude: try container.decode(Double.self, forKey: .latitude),
            longitude: try container.decode(Double.self, forKey: .longitude)
        )

        let hourly = try container.nestedContainer(keyedBy: HourlyKeys.self, forKey: .hourly)
        let times = try hourly.decode([TimeInterval].self, forKey: .time)
        let probabilities = try hourly.decode([Double?].self, forKey: .precipitationProbability)
        let precipitations = try hourly.decode([Double?].self, forKey: .precipitation)

        guard probabilities.count == times.count, precipitations.count == times.count else {
            throw DecodingError.dataCorrupted(DecodingError.Context(
                codingPath: hourly.codingPath,
                debugDescription: "Hourly arrays have different lengths: \(times.count) times, "
                    + "\(probabilities.count) probabilities, \(precipitations.count) precipitations."
            ))
        }

        samples = times.indices.map { index in
            WeatherSample(
                time: Date(timeIntervalSince1970: times[index]),
                precipitationProbability: probabilities[index] ?? 0,
                precipitation: precipitations[index] ?? 0
            )
        }
    }
}
