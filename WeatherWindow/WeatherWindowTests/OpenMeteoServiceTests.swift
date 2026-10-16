//
//  OpenMeteoServiceTests.swift
//  WeatherWindowTests
//
//  Created by Clement Boudon on 7/10/2026.
//

import Foundation
import Testing
@testable import WeatherWindow

struct OpenMeteoServiceTests {
    @Test func serverErrorBecomesARetryLaterMessage() {
        let error = failure(status: 503)

        #expect(error == .httpStatus(503))
        #expect(error?.errorDescription == "Weather service unavailable, try again in a minute.")
    }

    @Test func tooManyRequestsIsRateLimited() {
        #expect(failure(status: 429) == .rateLimited)
    }

    @Test func unreadableBodyIsAnInvalidResponse() {
        #expect(failure(status: 200, body: "<html>maintenance</html>") == .invalidResponse)
    }

    @Test func noConnectionIsOffline() {
        #expect(ServiceError(URLError(.notConnectedToInternet)) == .offline)
    }

    private func failure(status: Int, body: String = "") -> ServiceError? {
        let url = URL(string: "https://api.open-meteo.com/v1/forecast")!
        let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: nil)!
        do {
            try ServiceError.check(response)
            _ = try OpenMeteoService.forecastHours(from: Data(body.utf8))
            return nil
        } catch {
            return ServiceError(error)
        }
    }
}
