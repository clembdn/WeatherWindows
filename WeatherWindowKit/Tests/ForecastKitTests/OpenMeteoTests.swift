import Foundation
import Testing
import WeatherWindowCore
@testable import ForecastKit

@Test func decodesHourlyFixture() throws {
    let url = try #require(Bundle.module.url(forResource: "hourly_melbourne", withExtension: "json", subdirectory: "Fixtures"))

    let response = try JSONDecoder().decode(OpenMeteoHourlyResponse.self, from: Data(contentsOf: url))

    #expect(response.samples.count == 48)
    #expect(response.samples.first?.time == Date(timeIntervalSince1970: 1_790_985_600))
    #expect(response.samples.first?.precipitationProbability == 100)
    #expect(response.samples.first?.precipitation == 0.7)
}

@Test func toleratesNullValues() throws {
    let json = """
        {"latitude": -37.8, "longitude": 144.9, "hourly": {
            "time": [1790985600, 1790989200],
            "precipitation_probability": [null, 40],
            "precipitation": [1.5, null]
        }}
        """

    let response = try JSONDecoder().decode(OpenMeteoHourlyResponse.self, from: Data(json.utf8))

    #expect(response.samples.map(\.precipitationProbability) == [0, 40])
    #expect(response.samples.map(\.precipitation) == [1.5, 0])
}

@Test func rejectsMismatchedArrays() {
    let json = """
        {"latitude": -37.8, "longitude": 144.9, "hourly": {
            "time": [1790985600, 1790989200],
            "precipitation_probability": [10],
            "precipitation": [0.0, 0.2]
        }}
        """

    #expect {
        try JSONDecoder().decode(OpenMeteoHourlyResponse.self, from: Data(json.utf8))
    } throws: { error in
        guard case DecodingError.dataCorrupted = error else { return false }
        return true
    }
}

@Test func buildsHourlyForecastURL() throws {
    let url = try #require(OpenMeteoRequest.hourlyForecastURL(at: GeoPoint(latitude: -37.8136, longitude: 144.9631)))

    #expect(url.absoluteString == "https://api.open-meteo.com/v1/forecast?latitude=-37.8136&longitude=144.9631"
        + "&hourly=precipitation_probability,precipitation&timeformat=unixtime&forecast_days=2")
}

@Test func hourlySampleCoversThePrecedingHour() {
    let fourPM = Date(timeIntervalSince1970: 1_791_007_200)
    let field = HourlyRainField(samples: [
        WeatherSample(time: fourPM, precipitationProbability: 100, precipitation: 2),
        WeatherSample(time: fourPM.addingTimeInterval(3600), precipitationProbability: 50, precipitation: 0.4)
    ])
    let anywhere = GeoPoint(latitude: 0, longitude: 0)

    #expect(field.weight(at: anywhere, time: fourPM.addingTimeInterval(-30 * 60)) == 1)
    #expect(field.weight(at: anywhere, time: fourPM) == 0.2)
    #expect(field.weight(at: anywhere, time: fourPM.addingTimeInterval(3599)) == 0.2)
}

@Test func outsideTheForecastIsDry() {
    let fourPM = Date(timeIntervalSince1970: 1_791_007_200)
    let field = HourlyRainField(samples: [WeatherSample(time: fourPM, precipitationProbability: 100, precipitation: 2)])
    let anywhere = GeoPoint(latitude: 0, longitude: 0)

    #expect(field.weight(at: anywhere, time: fourPM.addingTimeInterval(-2 * 3600)) == 0)
    #expect(field.weight(at: anywhere, time: fourPM.addingTimeInterval(60)) == 0)
}
