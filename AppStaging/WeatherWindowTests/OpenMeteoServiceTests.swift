import Foundation
import Testing
import WeatherWindowCore
@testable import WeatherWindow

struct OpenMeteoServiceTests {
    @Test func serverErrorBecomesARetryLaterMessage() async {
        let error = await failure(status: 503)
        #expect(error == .httpStatus(503))
        #expect(error?.errorDescription == "Weather service unavailable, try again in a minute.")
    }

    @Test func tooManyRequestsIsRateLimited() async {
        #expect(await failure(status: 429) == .rateLimited)
    }

    @Test func unreadableBodyIsAnInvalidResponse() async {
        #expect(await failure(status: 200, body: "<html>maintenance</html>") == .invalidResponse)
    }

    @Test func noConnectionIsOffline() async {
        let service = OpenMeteoService(load: { _ in throw URLError(.notConnectedToInternet) })
        await #expect(throws: ServiceError.offline) {
            try await service.hourlyForecast(at: .melbourneCBD)
        }
    }

    @Test func cancellationIsNotReportedAsAnError() async {
        let service = OpenMeteoService(load: { _ in throw URLError(.cancelled) })
        await #expect(throws: CancellationError.self) {
            try await service.hourlyForecast(at: .melbourneCBD)
        }
    }

    @Test func decodesASuccessfulResponse() async throws {
        let body = #"{"latitude":-37.8,"longitude":144.9,"hourly":{"time":[1790985600],"precipitation_probability":[60],"precipitation":[0.5]}}"#
        let service = OpenMeteoService(load: { url in (Data(body.utf8), Self.response(url, status: 200)) })

        let samples = try await service.hourlyForecast(at: .melbourneCBD)

        #expect(samples.count == 1)
        #expect(abs(samples[0].rainWeight - 0.3) < 1e-9)
    }

    private func failure(status: Int, body: String = "") async -> ServiceError? {
        let service = OpenMeteoService(load: { url in (Data(body.utf8), Self.response(url, status: status)) })
        do {
            _ = try await service.hourlyForecast(at: .melbourneCBD)
            return nil
        } catch {
            return error as? ServiceError
        }
    }

    private static func response(_ url: URL, status: Int) -> URLResponse {
        HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: nil) ?? URLResponse()
    }
}
