import Foundation
import MapKit
import SolverKit
import Testing
import WeatherWindowCore
@testable import WeatherWindow

struct ServiceErrorTests {
    @Test func mapsSystemErrors() {
        #expect(ServiceError(URLError(.notConnectedToInternet)) == .offline)
        #expect(ServiceError(URLError(.timedOut)) == .timedOut)
        #expect(ServiceError(MKError(.loadingThrottled)) == .mapsThrottled)
        #expect(ServiceError(ServiceError.rateLimited) == .rateLimited)
    }

    @Test func serverErrorsSayToRetryLater() {
        #expect(ServiceError.httpStatus(503).errorDescription == "Weather service unavailable, try again in a minute.")
        #expect(ServiceError.httpStatus(404).errorDescription == "The service returned an error (HTTP 404).")
    }

    @Test func cacheKeyChangesWithThePlaces() {
        let cbd = GeoPoint.melbourneCBD
        let library = GeoPoint(latitude: -37.8098, longitude: 144.9652)

        #expect(CachedWalkingTime.key(from: cbd, to: library) == CachedWalkingTime.key(from: cbd, to: library))
        #expect(CachedWalkingTime.key(from: cbd, to: library) != CachedWalkingTime.key(from: library, to: cbd))
    }

    @Test func fourStopsNeedTwentyWalkingTimes() {
        let stops = (0..<4).map {
            Stop(name: "Stop \($0)", location: .melbourneCBD, serviceDuration: 600, openingMinute: 0, closingMinute: 1440)
        }
        #expect(WalkingMatrixBuilder.edges(for: stops).count == 20)
    }
}
