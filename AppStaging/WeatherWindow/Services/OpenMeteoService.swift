import ForecastKit
import Foundation
import WeatherWindowCore

// Downloads the hourly rain forecast from Open-Meteo.
struct OpenMeteoService {
    func hourlyForecast(at point: GeoPoint) async throws -> [WeatherSample] {
        guard let url = OpenMeteoRequest.hourlyForecastURL(at: point) else {
            throw ServiceError.invalidResponse
        }
        let (data, response) = try await URLSession.shared.data(from: url)
        return try Self.samples(from: data, response: response)
    }

    // Kept apart from the download so the tests can check every kind of answer without a server.
    static func samples(from data: Data, response: URLResponse) throws -> [WeatherSample] {
        try ServiceError.check(response)
        return try JSONDecoder().decode(OpenMeteoHourlyResponse.self, from: data).samples
    }
}
