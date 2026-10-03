import CoreLocation
import OSLog
import WeatherWindowCore

/// Gives one fresh position, asking for "when in use" access the first time it is needed.
@Observable
final class LocationService {
    private(set) var isDenied = false

    func currentLocation(timeout: Duration = .seconds(15)) async throws -> GeoPoint {
        let session = CLServiceSession(authorization: .whenInUse)
        defer { session.invalidate() }

        do {
            let point = try await withThrowingTaskGroup(of: GeoPoint.self) { group in
                group.addTask { try await Self.firstLocation() }
                group.addTask {
                    try await Task.sleep(for: timeout)
                    throw ServiceError.locationUnavailable
                }
                defer { group.cancelAll() }
                guard let point = try await group.next() else { throw ServiceError.locationUnavailable }
                return point
            }
            isDenied = false
            return point
        } catch ServiceError.locationDenied {
            isDenied = true
            throw ServiceError.locationDenied
        }
    }

    private nonisolated static func firstLocation() async throws -> GeoPoint {
        for try await update in CLLocationUpdate.liveUpdates() {
            if update.authorizationDenied || update.authorizationDeniedGlobally || update.authorizationRestricted {
                Logger.location.info("Location access denied")
                throw ServiceError.locationDenied
            }
            if let location = update.location, location.horizontalAccuracy >= 0 {
                return GeoPoint(location.coordinate)
            }
        }
        throw ServiceError.locationUnavailable
    }
}
