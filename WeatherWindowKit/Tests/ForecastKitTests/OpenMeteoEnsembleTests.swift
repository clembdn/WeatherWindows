import Foundation
import Testing
import WeatherWindowCore
@testable import ForecastKit

@Test func decodesEnsembleFixture() throws {
    let url = try #require(Bundle.module.url(forResource: "ensemble_melbourne", withExtension: "json", subdirectory: "Fixtures"))

    let response = try JSONDecoder().decode(OpenMeteoEnsembleResponse.self, from: Data(contentsOf: url))

    #expect(response.times.count == 48)
    #expect(response.times.first == Date(timeIntervalSince1970: 1_791_763_200))
    #expect(response.members.count == 40)
    #expect(response.members.allSatisfy { $0.count == 48 })
}

@Test func picksFiveRunsFromDryToWet() throws {
    // Five runs giving 0, 0.4, 1, 2 and 6 mm over the two hours.
    let json = """
        {"hourly": {
            "time": [1790989200, 1790992800],
            "precipitation": [0.5, 0.5],
            "precipitation_member01": [0, 0],
            "precipitation_member02": [3, 3],
            "precipitation_member03": [0.2, 0.2],
            "precipitation_member04": [1, 1]
        }}
        """
    let response = try JSONDecoder().decode(OpenMeteoEnsembleResponse.self, from: Data(json.utf8))
    let start = Date(timeIntervalSince1970: 1_790_985_600)

    let scenarios = response.scenarios(from: start, to: start.addingTimeInterval(2 * 3600))

    // Median first, then the 10th, 30th, 70th and 90th percentiles.
    let weights = scenarios.map { $0.weight(at: GeoPoint(latitude: -37.81, longitude: 144.96), time: start.addingTimeInterval(1800)) }
    #expect(weights == [0.5, 0, 0.2, 1, 1])
}

@Test func rejectsAnEnsembleWithoutRain() {
    let json = """
        {"hourly": {"time": [1790989200]}}
        """

    #expect(throws: DecodingError.self) {
        try JSONDecoder().decode(OpenMeteoEnsembleResponse.self, from: Data(json.utf8))
    }
}

@Test func buildsEnsembleURL() throws {
    let url = try #require(OpenMeteoRequest.ensembleURL(at: GeoPoint(latitude: -37.8136, longitude: 144.9631)))
    let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))

    #expect(components.host == "ensemble-api.open-meteo.com")
    #expect(components.queryItems?.contains(URLQueryItem(name: "models", value: "icon_seamless")) == true)
    #expect(components.queryItems?.contains(URLQueryItem(name: "timeformat", value: "unixtime")) == true)
}
