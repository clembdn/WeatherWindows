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
