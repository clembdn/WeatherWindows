import Foundation

/// A rectangle of tile pixels: only this area is extrapolated, to save time.
public struct PixelRegion: Hashable, Sendable {
    public var minX: Int
    public var minY: Int
    public var maxX: Int
    public var maxY: Int

    public init(minX: Int, minY: Int, maxX: Int, maxY: Int) {
        self.minX = minX
        self.minY = minY
        self.maxX = maxX
        self.maxY = maxY
    }

    public static func whole(size: Int) -> PixelRegion {
        PixelRegion(minX: 0, minY: 0, maxX: size - 1, maxY: size - 1)
    }

    /// The box around some pixels, widened by a margin and clipped to the tile.
    public static func around(_ pixels: [(x: Double, y: Double)], margin: Int, size: Int) -> PixelRegion {
        guard !pixels.isEmpty else { return .whole(size: size) }
        return PixelRegion(
            minX: max(0, Int(pixels.map(\.x).min() ?? 0) - margin),
            minY: max(0, Int(pixels.map(\.y).min() ?? 0) - margin),
            maxX: min(size - 1, Int((pixels.map(\.x).max() ?? 0).rounded(.up)) + margin),
            maxY: min(size - 1, Int((pixels.map(\.y).max() ?? 0).rounded(.up)) + margin)
        )
    }
}

/// Extrapolates the last radar image along the motion field, one frame per minute.
public enum Advector {
    /// Semi-Lagrangian backward scheme: each future pixel looks upstream for its value,
    /// I(t0 + k)(x) = I(t0)(x − k/10 · v(x)), so no pixel is left empty. Outside `region` stays dry.
    public static func forecast(from frame: RadarFrame, motion: MotionField,
                                minutes: ClosedRange<Int> = 1...30, region: PixelRegion? = nil) -> [RadarFrame] {
        let size = frame.grid.size
        let area = region ?? .whole(size: size)

        return minutes.map { minute in
            var grid = RainGrid.empty(size: size)
            let steps = Double(minute) / 10
            for y in area.minY...area.maxY {
                for x in area.minX...area.maxX {
                    let vector = motion.vector(atX: Double(x), y: Double(y))
                    grid[x, y] = frame.grid.sample(x: Double(x) - steps * vector.dx, y: Double(y) - steps * vector.dy)
                }
            }
            return RadarFrame(grid: grid, tile: frame.tile, time: frame.time.addingTimeInterval(TimeInterval(minute * 60)))
        }
    }
}
