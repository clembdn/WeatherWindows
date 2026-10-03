import Foundation
import OSLog
import SolverKit
import SwiftData
import WeatherWindowCore

/// Builds the solver's walking-time matrix: cached pairs first, Apple Maps for the rest.
struct WalkingMatrixBuilder {
    let context: ModelContext
    var directions = DirectionsService()
    /// 1.2 means the user walks 20 % slower than Apple Maps assumes.
    var paceFactor = 1.0
    var now = Date.now

    struct Result {
        let walkingTimes: [Node: [Node: TimeInterval]]
        let cachedCount: Int
        let requestedCount: Int
    }

    /// Start → each stop, stop → stop, each stop → end: 20 pairs for 4 stops.
    static func edges(for stops: [Stop]) -> [(Node, Node)] {
        guard !stops.isEmpty else { return [(.start, .end)] }
        let nodes = stops.map { Node.stop($0.id) }
        return nodes.map { (.start, $0) }
            + nodes.flatMap { from in nodes.filter { $0 != from }.map { (from, $0) } }
            + nodes.map { ($0, .end) }
    }

    func walkingTimes(start: GeoPoint, end: GeoPoint, stops: [Stop]) async throws -> Result {
        var places: [Node: GeoPoint] = [.start: start, .end: end]
        for stop in stops { places[.stop(stop.id)] = stop.location }

        let legs = Self.edges(for: stops).compactMap { edge -> (edge: (Node, Node), pair: WalkingPair)? in
            guard let from = places[edge.0], let to = places[edge.1] else { return nil }
            return (edge, WalkingPair(from: from, to: to))
        }
        let pairs = legs.map(\.pair)

        var seconds = try cachedSeconds(for: Set(pairs))
        let cachedCount = seconds.count
        let missing = Array(Set(pairs).filter { seconds[$0] == nil })
        if !missing.isEmpty {
            let fetched = try await directions.walkingTimes(for: missing)
            for (pair, time) in fetched {
                seconds[pair] = time
                context.insert(CachedWalkingTime(key: CachedWalkingTime.key(from: pair.from, to: pair.to),
                                                 seconds: time, createdAt: now))
            }
            do {
                try context.save()
            } catch {
                Logger.data.error("Walking times could not be cached: \(error.localizedDescription, privacy: .public)")
            }
        }

        var matrix: [Node: [Node: TimeInterval]] = [:]
        for leg in legs {
            matrix[leg.edge.0, default: [:]][leg.edge.1] = (seconds[leg.pair] ?? 0) * paceFactor
        }
        return Result(walkingTimes: matrix, cachedCount: cachedCount, requestedCount: missing.count)
    }

    private func cachedSeconds(for pairs: Set<WalkingPair>) throws -> [WalkingPair: TimeInterval] {
        let pairsByKey = Dictionary(pairs.map { (CachedWalkingTime.key(from: $0.from, to: $0.to), $0) },
                                    uniquingKeysWith: { first, _ in first })
        let keys = Array(pairsByKey.keys)
        let entries = try context.fetch(FetchDescriptor<CachedWalkingTime>(predicate: #Predicate { keys.contains($0.key) }))

        var seconds: [WalkingPair: TimeInterval] = [:]
        for entry in entries where entry.isFresh(at: now) {
            if let pair = pairsByKey[entry.key] { seconds[pair] = entry.seconds }
        }
        return seconds
    }
}
