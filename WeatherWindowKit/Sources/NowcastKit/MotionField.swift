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

/// How the rain moves: one vector per block of the tile, stored row by row.
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

    /// The same vector everywhere.
    public static func uniform(_ vector: MotionVector, gridSize: Int, blockSize: Int) -> MotionField {
        let columns = gridSize / blockSize
        return MotionField(blockSize: blockSize, columns: columns,
                           vectors: Array(repeating: vector, count: columns * columns), isGlobal: true)
    }

    /// The vector of one block.
    public subscript(column: Int, row: Int) -> MotionVector {
        vectors[row * columns + column]
    }

    /// Motion at a pixel, blended between the four closest block centres.
    public func vector(atX x: Double, y: Double) -> MotionVector {
        let half = Double(blockSize) / 2
        let gx = min(max((x - half) / Double(blockSize), 0), Double(columns - 1))
        let gy = min(max((y - half) / Double(blockSize), 0), Double(columns - 1))
        let c0 = Int(gx)
        let r0 = Int(gy)
        let c1 = min(c0 + 1, columns - 1)
        let r1 = min(r0 + 1, columns - 1)
        let fx = gx - Double(c0)
        let fy = gy - Double(r0)

        let topLeft = self[c0, r0]
        let topRight = self[c1, r0]
        let bottomLeft = self[c0, r1]
        let bottomRight = self[c1, r1]
        let dx = (topLeft.dx * (1 - fx) + topRight.dx * fx) * (1 - fy) + (bottomLeft.dx * (1 - fx) + bottomRight.dx * fx) * fy
        let dy = (topLeft.dy * (1 - fx) + topRight.dy * fx) * (1 - fy) + (bottomLeft.dy * (1 - fx) + bottomRight.dy * fx) * fy
        return MotionVector(dx: dx, dy: dy)
    }
}
