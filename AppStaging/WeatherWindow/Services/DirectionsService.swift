import MapKit
import WeatherWindowCore

/// An ordered pair of places whose walking time is needed.
nonisolated struct WalkingPair: Hashable, Sendable {
    let from: GeoPoint
    let to: GeoPoint
}

/// Asks Apple Maps for walking times, at most three at a time, retrying when Maps throttles.
struct DirectionsService {
    static let maxConcurrentRequests = 3
    static let retryDelays: [Duration] = [.seconds(2), .seconds(5)]

    func walkingTime(for pair: WalkingPair) async throws -> TimeInterval {
        guard pair.from != pair.to else { return 0 }

        var attempt = 0
        while true {
            do {
                let request = MKDirections.Request()
                request.source = MKMapItem(placemark: MKPlacemark(coordinate: pair.from.coordinate))
                request.destination = MKMapItem(placemark: MKPlacemark(coordinate: pair.to.coordinate))
                request.transportType = .walking
                return try await MKDirections(request: request).calculateETA().expectedTravelTime
            } catch {
                let serviceError = ServiceError(error)
                guard serviceError == .mapsThrottled, attempt < Self.retryDelays.count else { throw serviceError }
                try await Task.sleep(for: Self.retryDelays[attempt])
                attempt += 1
            }
        }
    }

    func walkingTimes(for pairs: [WalkingPair]) async throws -> [WalkingPair: TimeInterval] {
        try await withThrowingTaskGroup(of: (WalkingPair, TimeInterval).self) { group in
            var remaining = pairs.makeIterator()
            for _ in 0..<Self.maxConcurrentRequests {
                guard let pair = remaining.next() else { break }
                group.addTask { (pair, try await walkingTime(for: pair)) }
            }

            var times: [WalkingPair: TimeInterval] = [:]
            while let (pair, time) = try await group.next() {
                times[pair] = time
                if let next = remaining.next() {
                    group.addTask { (next, try await walkingTime(for: next)) }
                }
            }
            return times
        }
    }
}
