//
//  DirectionsService.swift
//  WeatherWindow
//
//  Created by Clement Boudon on 7/10/2026.
//

import MapKit
import OSLog
import SwiftData

private let logger = Logger(subsystem: "edu.monash.cboudon.WeatherWindow", category: "maps")

struct DirectionsService {
    let context: ModelContext
    var paceFactor = 1.0

    struct WalkingMatrix {
        var times: [Waypoint: [Waypoint: TimeInterval]] = [:]
        var fromCache = 0
        var requested = 0
    }

    func walkingMatrix(start: GeoPoint, end: GeoPoint, stops: [Stop]) async throws -> WalkingMatrix {
        var matrix = WalkingMatrix()
        for pair in PlanRequest.neededPairs(for: stops) {
            let from = pair.from.location(start: start, end: end, stops: stops)
            let to = pair.to.location(start: start, end: end, stops: stops)
            let key = CachedWalkingTime.key(from: from, to: to)

            let seconds: TimeInterval
            if let cached = cachedSeconds(forKey: key) {
                seconds = cached
                matrix.fromCache += 1
            } else {
                seconds = try await walkingTime(from: from, to: to)
                context.insert(CachedWalkingTime(key: key, seconds: seconds))
                matrix.requested += 1
            }
            matrix.times[pair.from, default: [:]][pair.to] = seconds * paceFactor
        }

        if matrix.requested > 0 {
            do {
                try context.save()
            } catch {
                logger.error("Walking times could not be cached: \(error.localizedDescription)")
            }
        }
        return matrix
    }

    func walkingTime(from origin: GeoPoint, to destination: GeoPoint) async throws -> TimeInterval {
        if origin == destination {
            return 0
        }
        let request = walkingRequest(from: origin, to: destination)
        do {
            return try await MKDirections(request: request).calculateETA().expectedTravelTime
        } catch let error as MKError where error.code == .loadingThrottled {
            try await Task.sleep(for: .seconds(3))
            return try await MKDirections(request: request).calculateETA().expectedTravelTime
        }
    }

    func routeLine(from origin: GeoPoint, to destination: GeoPoint) async -> [GeoPoint] {
        let straightLine = [origin, destination]
        if origin == destination {
            return straightLine
        }
        do {
            let response = try await MKDirections(request: walkingRequest(from: origin, to: destination)).calculate()
            guard let polyline = response.routes.first?.polyline else { return straightLine }
            var coordinates = [CLLocationCoordinate2D](repeating: kCLLocationCoordinate2DInvalid, count: polyline.pointCount)
            polyline.getCoordinates(&coordinates, range: NSRange(location: 0, length: polyline.pointCount))
            return coordinates.map { GeoPoint($0) }
        } catch {
            logger.info("No walking route, drawing a straight line: \(error.localizedDescription)")
            return straightLine
        }
    }

    private func cachedSeconds(forKey key: String) -> TimeInterval? {
        let descriptor = FetchDescriptor<CachedWalkingTime>(predicate: #Predicate { $0.key == key })
        guard let entry = try? context.fetch(descriptor).first else { return nil }
        let week: TimeInterval = 7 * 24 * 3600
        if Date.now.timeIntervalSince(entry.createdAt) > week {
            return nil
        }
        return entry.seconds
    }

    private func walkingRequest(from origin: GeoPoint, to destination: GeoPoint) -> MKDirections.Request {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: origin.coordinate))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destination.coordinate))
        request.transportType = .walking
        return request
    }
}
