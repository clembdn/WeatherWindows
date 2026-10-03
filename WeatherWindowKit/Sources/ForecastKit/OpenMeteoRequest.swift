import Foundation
import WeatherWindowCore

/// Builds Open-Meteo forecast URLs.
public enum OpenMeteoRequest {
    /// Hourly rain probability and amount, with Unix timestamps so no local-time string is ever parsed.
    public static func hourlyForecastURL(at point: GeoPoint, forecastDays: Int = 2) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "api.open-meteo.com"
        components.path = "/v1/forecast"
        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(format: "%.4f", point.latitude)),
            URLQueryItem(name: "longitude", value: String(format: "%.4f", point.longitude)),
            URLQueryItem(name: "hourly", value: "precipitation_probability,precipitation"),
            URLQueryItem(name: "timeformat", value: "unixtime"),
            URLQueryItem(name: "forecast_days", value: String(forecastDays))
        ]
        return components.url
    }
}
