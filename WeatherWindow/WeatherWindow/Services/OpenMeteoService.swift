//
//  OpenMeteoService.swift
//  WeatherWindow
//
//  Created by Clement Boudon on 7/10/2026.
//

import Foundation

struct OpenMeteoService {
    func hourlyForecast(at point: GeoPoint) async throws -> [ForecastHour] {
        guard let url = Self.hourlyURL(at: point) else {
            throw ServiceError.invalidResponse
        }
        let (data, response) = try await URLSession.shared.data(from: url)
        try ServiceError.check(response)
        return try Self.forecastHours(from: data)
    }

    func ensemble(at point: GeoPoint) async throws -> Ensemble {
        guard let url = Self.ensembleURL(at: point) else {
            throw ServiceError.invalidResponse
        }
        let (data, response) = try await URLSession.shared.data(from: url)
        try ServiceError.check(response)
        return try Self.ensemble(from: data)
    }

    static func hourlyURL(at point: GeoPoint) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "api.open-meteo.com"
        components.path = "/v1/forecast"
        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(format: "%.4f", point.latitude)),
            URLQueryItem(name: "longitude", value: String(format: "%.4f", point.longitude)),
            URLQueryItem(name: "hourly", value: "precipitation_probability,precipitation"),
            URLQueryItem(name: "timeformat", value: "unixtime"),
            URLQueryItem(name: "forecast_days", value: "2")
        ]
        return components.url
    }

    static func ensembleURL(at point: GeoPoint) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "ensemble-api.open-meteo.com"
        components.path = "/v1/ensemble"
        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(format: "%.4f", point.latitude)),
            URLQueryItem(name: "longitude", value: String(format: "%.4f", point.longitude)),
            URLQueryItem(name: "hourly", value: "precipitation"),
            URLQueryItem(name: "models", value: "icon_seamless"),
            URLQueryItem(name: "timeformat", value: "unixtime"),
            URLQueryItem(name: "forecast_days", value: "2")
        ]
        return components.url
    }

    static func forecastHours(from data: Data) throws -> [ForecastHour] {
        let hourly = try JSONDecoder().decode(OpenMeteoResponse.self, from: data).hourly
        guard hourly.precipitationProbability.count == hourly.time.count,
              hourly.precipitation.count == hourly.time.count else {
            throw ServiceError.invalidResponse
        }

        var hours: [ForecastHour] = []
        for index in hourly.time.indices {
            hours.append(ForecastHour(
                time: Date(timeIntervalSince1970: hourly.time[index]),
                precipitationProbability: hourly.precipitationProbability[index] ?? 0,
                precipitation: hourly.precipitation[index] ?? 0
            ))
        }
        return hours
    }

    static func ensemble(from data: Data) throws -> Ensemble {
        let hourly = try JSONDecoder().decode(EnsembleResponse.self, from: data).hourly
        guard let seconds = hourly["time"] else {
            throw ServiceError.invalidResponse
        }

        var members: [[Double]] = []
        for key in hourly.keys.sorted() where key.hasPrefix("precipitation") {
            let values = hourly[key] ?? []
            guard values.count == seconds.count else {
                throw ServiceError.invalidResponse
            }
            members.append(values.map { $0 ?? 0 })
        }
        if members.isEmpty {
            throw ServiceError.invalidResponse
        }

        let times = seconds.map { Date(timeIntervalSince1970: $0 ?? 0) }
        return Ensemble(times: times, members: members)
    }
}

nonisolated struct OpenMeteoResponse: Decodable {
    let hourly: HourlyData
}

nonisolated struct HourlyData: Decodable {
    let time: [TimeInterval]
    let precipitationProbability: [Double?]
    let precipitation: [Double?]

    private enum CodingKeys: String, CodingKey {
        case time
        case precipitationProbability = "precipitation_probability"
        case precipitation
    }
}

nonisolated struct EnsembleResponse: Decodable {
    let hourly: [String: [Double?]]
}
