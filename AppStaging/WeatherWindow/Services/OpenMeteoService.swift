import ForecastKit
import Foundation
import OSLog
import WeatherWindowCore

/// Downloads the hourly rain forecast from Open-Meteo.
struct OpenMeteoService {
    /// The network call, replaceable in tests to provoke HTTP errors without a server.
    var load: (URL) async throws -> (Data, URLResponse) = { url in try await URLSession.shared.data(from: url) }

    func hourlyForecast(at point: GeoPoint) async throws -> [WeatherSample] {
        guard let url = OpenMeteoRequest.hourlyForecastURL(at: point) else {
            throw ServiceError.invalidResponse
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await load(url)
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch {
            Logger.network.error("Open-Meteo request failed: \(error.localizedDescription, privacy: .public)")
            throw ServiceError(error)
        }

        guard let http = response as? HTTPURLResponse else { throw ServiceError.invalidResponse }
        switch http.statusCode {
        case 200...299: break
        case 429: throw ServiceError.rateLimited
        default: throw ServiceError.httpStatus(http.statusCode)
        }

        do {
            return try JSONDecoder().decode(OpenMeteoHourlyResponse.self, from: data).samples
        } catch {
            Logger.network.error("Open-Meteo response could not be decoded: \(error.localizedDescription, privacy: .public)")
            throw ServiceError.invalidResponse
        }
    }
}
