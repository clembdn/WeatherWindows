/// A displacement in pixels per 10 minutes (the time between two radar images).
public struct MotionVector: Hashable, Sendable {
    public var dx: Double
    public var dy: Double

    public init(dx: Double, dy: Double) {
        self.dx = dx
        self.dy = dy
    }

    public static let zero = MotionVector(dx: 0, dy: 0)
}

/// How the rain moves: one vector per block of the tile.
public struct MotionField: Hashable, Sendable {
    public let blockSize: Int
    public let columns: Int
    public let vectors: [MotionVector]
    /// True when too little rain was found to trust blocks, so one vector describes the whole tile.
    public let isGlobal: Bool

    public init(blockSize: Int, columns: Int, vectors: [MotionVector], isGlobal: Bool) {
        precondition(vectors.count == columns * columns, "A MotionField needs columns × columns vectors")
        self.blockSize = blockSize
        self.columns = columns
        self.vectors = vectors
        self.isGlobal = isGlobal
    }

    public static func uniform(_ vector: MotionVector, gridSize: Int, blockSize: Int) -> MotionField {
        let columns = gridSize / blockSize
        return MotionField(blockSize: blockSize, columns: columns,
                           vectors: Array(repeating: vector, count: columns * columns), isGlobal: true)
    }

    public subscript(column: Int, row: Int) -> MotionVector {
        vectors[row * columns + column]
    }

    /// Motion at a pixel, interpolated between block centres.
    public func vector(atX x: Double, y: Double) -> MotionVector {
        let half = Double(blockSize) / 2
        let gx = min(max((x - half) / Double(blockSize), 0), Double(columns - 1))
        let gy = min(max((y - half) / Double(blockSize), 0), Double(columns - 1))
        let c0 = Int(gx), r0 = Int(gy)
        let c1 = min(c0 + 1, columns - 1), r1 = min(r0 + 1, columns - 1)
        let fx = gx - Double(c0), fy = gy - Double(r0)

        func blend(_ value: (MotionVector) -> Double) -> Double {
            let top = value(self[c0, r0]) * (1 - fx) + value(self[c1, r0]) * fx
            let bottom = value(self[c0, r1]) * (1 - fx) + value(self[c1, r1]) * fx
            return top * (1 - fy) + bottom * fy
        }
        return MotionVector(dx: blend(\.dx), dy: blend(\.dy))
    }

    /// Mean of all block vectors.
    public var meanVector: MotionVector {
        let count = Double(vectors.count)
        return MotionVector(dx: vectors.map(\.dx).reduce(0, +) / count, dy: vectors.map(\.dy).reduce(0, +) / count)
    }
}
