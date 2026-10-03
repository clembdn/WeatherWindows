/// Radar reflectivity in dBZ on a square tile, stored row by row.
public struct RainGrid: Sendable, Equatable {
    public let size: Int
    public var values: [Float]

    public init(size: Int, values: [Float]) {
        precondition(values.count == size * size, "A RainGrid needs size × size values")
        self.size = size
        self.values = values
    }

    public subscript(x: Int, y: Int) -> Float {
        values[y * size + x]
    }
}
