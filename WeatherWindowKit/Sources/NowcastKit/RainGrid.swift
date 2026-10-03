import Foundation
import WeatherWindowCore

/// Radar reflectivity in dBZ on a square tile, stored row by row.
public struct RainGrid: Sendable, Equatable {
    public let size: Int
    public var values: [Float]

    public init(size: Int, values: [Float]) {
        precondition(values.count == size * size, "A RainGrid needs size × size values")
        self.size = size
        self.values = values
    }

    /// A grid where the radar sees nothing.
    public static func empty(size: Int) -> RainGrid {
        RainGrid(size: size, values: [Float](repeating: ReflectivityPalette.noEchoDBZ, count: size * size))
    }

    public subscript(x: Int, y: Int) -> Float {
        get { values[y * size + x] }
        set { values[y * size + x] = newValue }
    }

    /// Bilinear reading between pixel centres; outside the tile the radar sees nothing.
    public func sample(x: Double, y: Double) -> Float {
        guard x >= 0, y >= 0, x <= Double(size - 1), y <= Double(size - 1) else {
            return ReflectivityPalette.noEchoDBZ
        }
        let x0 = Int(x), y0 = Int(y)
        let x1 = min(x0 + 1, size - 1), y1 = min(y0 + 1, size - 1)
        let fx = Float(x - Double(x0)), fy = Float(y - Double(y0))

        let top = self[x0, y0] * (1 - fx) + self[x1, y0] * fx
        let bottom = self[x0, y1] * (1 - fx) + self[x1, y1] * fx
        return top * (1 - fy) + bottom * fy
    }
}

/// One radar image: its grid, the tile it covers and when it was captured.
public struct RadarFrame: Sendable, Equatable {
    public let grid: RainGrid
    public let tile: RadarTile
    public let time: Date

    public init(grid: RainGrid, tile: RadarTile = .melbourne, time: Date) {
        self.grid = grid
        self.tile = tile
        self.time = time
    }
}
