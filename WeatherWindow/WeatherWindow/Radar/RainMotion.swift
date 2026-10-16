//
//  RainMotion.swift
//  WeatherWindow
//
//  Created by Clement Boudon on 7/10/2026.
//

nonisolated struct Movement: Hashable {
    var dx: Double
    var dy: Double

    static let zero = Movement(dx: 0, dy: 0)
}

nonisolated struct RainMotion: Hashable {
    let blockSize: Int
    let columns: Int
    let movements: [Movement]
    let isGlobal: Bool

    init(blockSize: Int, columns: Int, movements: [Movement], isGlobal: Bool) {
        precondition(movements.count == columns * columns, "A RainMotion needs columns × columns movements")
        self.blockSize = blockSize
        self.columns = columns
        self.movements = movements
        self.isGlobal = isGlobal
    }

    static func uniform(_ movement: Movement, gridSize: Int, blockSize: Int) -> RainMotion {
        let columns = gridSize / blockSize
        return RainMotion(blockSize: blockSize, columns: columns,
                          movements: Array(repeating: movement, count: columns * columns), isGlobal: true)
    }

    subscript(column: Int, row: Int) -> Movement {
        movements[row * columns + column]
    }

    func movement(atX x: Double, y: Double) -> Movement {
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
        return Movement(dx: dx, dy: dy)
    }
}
