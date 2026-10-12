/// Cuts a route line into dry and rainy pieces, so the map can draw them differently.
public enum RouteGeometry {
    /// A piece of route and whether it is expected to be rainy.
    public struct Segment: Hashable, Sendable {
        public let points: [GeoPoint]
        public let isRainy: Bool
    }

    /// The part of the line between two fractions (0...1) of its length.
    public static func slice(_ line: [GeoPoint], from start: Double, to end: Double) -> [GeoPoint] {
        guard line.count > 1, end > start else { return [] }

        var lengths: [Double] = []
        for index in 1..<line.count {
            lengths.append(line[index - 1].distance(to: line[index]))
        }
        let total = lengths.reduce(0, +)
        guard total > 0 else { return [line[0], line[0]] }

        let startDistance = max(0, start) * total
        let endDistance = min(1, end) * total
        var result: [GeoPoint] = []
        var travelled = 0.0

        for index in 0..<lengths.count {
            let length = lengths[index]
            let pieceStart = travelled
            let pieceEnd = travelled + length
            travelled = pieceEnd
            if length == 0 || pieceEnd < startDistance || pieceStart > endDistance {
                continue
            }

            let a = line[index]
            let b = line[index + 1]
            let first = interpolate(a, b, (max(startDistance, pieceStart) - pieceStart) / length)
            let last = interpolate(a, b, (min(endDistance, pieceEnd) - pieceStart) / length)
            if result.last != first {
                result.append(first)
            }
            result.append(last)
        }
        return result
    }

    /// Splits a line walked in `rainyMinutes.count` equal minutes into runs of dry or rainy minutes.
    public static func segments(of line: [GeoPoint], rainyMinutes: [Bool]) -> [Segment] {
        if rainyMinutes.isEmpty {
            return line.count > 1 ? [Segment(points: line, isRainy: false)] : []
        }

        let minutes = Double(rainyMinutes.count)
        var segments: [Segment] = []
        var runStart = 0
        for index in 1...rainyMinutes.count {
            let runEnds = index == rainyMinutes.count || rainyMinutes[index] != rainyMinutes[runStart]
            if !runEnds {
                continue
            }
            let points = slice(line, from: Double(runStart) / minutes, to: Double(index) / minutes)
            if points.count > 1 {
                segments.append(Segment(points: points, isRainy: rainyMinutes[runStart]))
            }
            runStart = index
        }
        return segments
    }

    private static func interpolate(_ a: GeoPoint, _ b: GeoPoint, _ t: Double) -> GeoPoint {
        GeoPoint(latitude: a.latitude + (b.latitude - a.latitude) * t,
                 longitude: a.longitude + (b.longitude - a.longitude) * t)
    }
}
