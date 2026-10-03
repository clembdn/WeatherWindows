/// Cuts a route line into pieces by share of its length, to style dry and rainy stretches differently.
public enum RouteGeometry {
    /// A stretch of route and whether it is expected to be rainy.
    public struct Segment: Hashable, Sendable {
        public let points: [GeoPoint]
        public let isRainy: Bool
    }

    /// The part of the line between two fractions (0...1) of its length.
    public static func slice(_ line: [GeoPoint], from start: Double, to end: Double) -> [GeoPoint] {
        guard line.count > 1, end > start else { return [] }
        let lengths = zip(line, line.dropFirst()).map { $0.distance(to: $1) }
        let total = lengths.reduce(0, +)
        guard total > 0 else { return [line[0], line[0]] }

        let startDistance = max(0, start) * total
        let endDistance = min(1, end) * total
        var result: [GeoPoint] = []
        var travelled = 0.0
        for (index, length) in lengths.enumerated() {
            let a = line[index], b = line[index + 1]
            let segmentEnd = travelled + length
            if segmentEnd >= startDistance, travelled <= endDistance, length > 0 {
                let from = max(startDistance, travelled), to = min(endDistance, segmentEnd)
                let first = interpolate(a, b, (from - travelled) / length)
                if result.last != first { result.append(first) }
                result.append(interpolate(a, b, (to - travelled) / length))
            }
            travelled = segmentEnd
        }
        return result
    }

    /// Splits a line walked in `flags.count` equal minutes into runs of dry or rainy minutes.
    public static func segments(of line: [GeoPoint], rainyMinutes flags: [Bool]) -> [Segment] {
        guard !flags.isEmpty else { return line.count > 1 ? [Segment(points: line, isRainy: false)] : [] }
        var segments: [Segment] = []
        var runStart = 0
        for index in 1...flags.count where index == flags.count || flags[index] != flags[runStart] {
            let points = slice(line, from: Double(runStart) / Double(flags.count), to: Double(index) / Double(flags.count))
            if points.count > 1 { segments.append(Segment(points: points, isRainy: flags[runStart])) }
            runStart = index
        }
        return segments
    }

    private static func interpolate(_ a: GeoPoint, _ b: GeoPoint, _ t: Double) -> GeoPoint {
        GeoPoint(latitude: a.latitude + (b.latitude - a.latitude) * t,
                 longitude: a.longitude + (b.longitude - a.longitude) * t)
    }
}
