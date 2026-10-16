//
//  MotionFinder.swift
//  WeatherWindow
//
//  Created by Clement Boudon on 7/10/2026.
//

import Foundation

nonisolated struct MotionFinder {
    var blockSize = 16
    var searchRadius = 24
    var coarseStep = 3
    var minimumRainPixels = 16
    var minimumBlocks = 5
    var pairCount = 3

    static let noiseFloor: Float = 10

    func estimate(from frames: [RadarFrame], region: PixelBox? = nil) -> RainMotion {
        guard frames.count >= 2, let size = frames.first?.grid.size else {
            return .uniform(.zero, gridSize: max(frames.first?.grid.size ?? 0, blockSize), blockSize: blockSize)
        }

        let columns = size / blockSize
        var sums = [Movement](repeating: .zero, count: columns * columns)
        var counts = [Int](repeating: 0, count: columns * columns)
        var globalMovements: [Movement] = []

        let firstPair = max(0, frames.count - 1 - pairCount)
        for index in firstPair..<(frames.count - 1) {
            let earlier = frames[index]
            let later = frames[index + 1]
            let scale = 600 / max(later.time.timeIntervalSince(earlier.time), 60)
            let before = Self.intensity(earlier.grid)
            let after = Self.intensity(later.grid)

            let blocks = rainyBlocks(in: earlier.grid, columns: columns, region: region)
            if blocks.count >= minimumBlocks {
                for block in blocks {
                    let area = PixelBox(minX: block.column * blockSize, minY: block.row * blockSize,
                                        maxX: (block.column + 1) * blockSize - 1, maxY: (block.row + 1) * blockSize - 1)
                    let shift = bestShift(before, after, size: size, area: area)
                    let blockIndex = block.row * columns + block.column
                    sums[blockIndex].dx += Double(shift.dx) * scale
                    sums[blockIndex].dy += Double(shift.dy) * scale
                    counts[blockIndex] += 1
                }
            } else if !blocks.isEmpty {
                let area = PixelBox(minX: blocks.map(\.column).min()! * blockSize,
                                    minY: blocks.map(\.row).min()! * blockSize,
                                    maxX: (blocks.map(\.column).max()! + 1) * blockSize - 1,
                                    maxY: (blocks.map(\.row).max()! + 1) * blockSize - 1)
                let shift = bestShift(before, after, size: size, area: area)
                globalMovements.append(Movement(dx: Double(shift.dx) * scale, dy: Double(shift.dy) * scale))
            } else {
                globalMovements.append(.zero)
            }
        }

        var blockMovements: [Movement?] = []
        for blockIndex in sums.indices {
            if counts[blockIndex] > 0 {
                let count = Double(counts[blockIndex])
                blockMovements.append(Movement(dx: sums[blockIndex].dx / count, dy: sums[blockIndex].dy / count))
            } else {
                blockMovements.append(nil)
            }
        }

        let usableBlocks = counts.filter { $0 > 0 }.count
        if usableBlocks < minimumBlocks {
            var global = Movement.zero
            if !globalMovements.isEmpty {
                let count = Double(globalMovements.count)
                global = Movement(dx: globalMovements.map(\.dx).reduce(0, +) / count,
                                  dy: globalMovements.map(\.dy).reduce(0, +) / count)
            }
            return .uniform(global, gridSize: size, blockSize: blockSize)
        }

        let smoothed = Self.smooth(blockMovements, columns: columns)
        return RainMotion(blockSize: blockSize, columns: columns, movements: smoothed, isGlobal: false)
    }

    private func rainyBlocks(in grid: RainGrid, columns: Int, region: PixelBox?) -> [(row: Int, column: Int)] {
        var blocks: [(row: Int, column: Int)] = []
        for row in 0..<columns {
            for column in 0..<columns {
                let x = column * blockSize
                let y = row * blockSize
                if let region, x + blockSize <= region.minX || x > region.maxX
                    || y + blockSize <= region.minY || y > region.maxY {
                    continue
                }

                var rainPixels = 0
                for pixelY in y..<(y + blockSize) {
                    for pixelX in x..<(x + blockSize) where grid[pixelX, pixelY] >= RainRate.rainThresholdDBZ {
                        rainPixels += 1
                    }
                }
                if rainPixels >= minimumRainPixels {
                    blocks.append((row, column))
                }
            }
        }
        return blocks
    }

    private func bestShift(_ before: [Float], _ after: [Float], size: Int, area: PixelBox) -> (dx: Int, dy: Int) {
        var coarse: [(dx: Int, dy: Int)] = []
        for dy in stride(from: -searchRadius, through: searchRadius, by: coarseStep) {
            for dx in stride(from: -searchRadius, through: searchRadius, by: coarseStep) {
                coarse.append((dx, dy))
            }
        }
        let coarseBest = cheapestShift(among: coarse, before, after, size: size, area: area)

        var fine: [(dx: Int, dy: Int)] = []
        for dy in -coarseStep...coarseStep {
            for dx in -coarseStep...coarseStep {
                let shift = (dx: coarseBest.dx + dx, dy: coarseBest.dy + dy)
                if abs(shift.dx) <= searchRadius && abs(shift.dy) <= searchRadius {
                    fine.append(shift)
                }
            }
        }
        return cheapestShift(among: fine, before, after, size: size, area: area)
    }

    private func cheapestShift(among shifts: [(dx: Int, dy: Int)], _ before: [Float], _ after: [Float],
                               size: Int, area: PixelBox) -> (dx: Int, dy: Int) {
        var best = (dx: 0, dy: 0)
        var bestCost = Float.infinity
        for shift in shifts {
            var cost: Float = 0
            for y in area.minY...area.maxY {
                let movedY = y + shift.dy
                for x in area.minX...area.maxX {
                    let movedX = x + shift.dx
                    let isInside = movedY >= 0 && movedY < size && movedX >= 0 && movedX < size
                    let moved: Float = isInside ? after[movedY * size + movedX] : 0
                    cost += abs(before[y * size + x] - moved)
                }
            }

            let isSmaller = shift.dx * shift.dx + shift.dy * shift.dy < best.dx * best.dx + best.dy * best.dy
            if cost < bestCost || (cost == bestCost && isSmaller) {
                best = shift
                bestCost = cost
            }
        }
        return best
    }

    private static func intensity(_ grid: RainGrid) -> [Float] {
        grid.values.map { max(0, $0 - noiseFloor) }
    }

    private static func smooth(_ movements: [Movement?], columns: Int) -> [Movement] {
        let valid = movements.compactMap { $0 }
        let fallback = Movement(dx: median(valid.map(\.dx)), dy: median(valid.map(\.dy)))

        var smoothed: [Movement] = []
        for index in movements.indices {
            if movements[index] == nil {
                smoothed.append(fallback)
                continue
            }
            let row = index / columns
            let column = index % columns
            var neighbours: [Movement] = []
            for r in max(0, row - 1)...min(columns - 1, row + 1) {
                for c in max(0, column - 1)...min(columns - 1, column + 1) {
                    if let movement = movements[r * columns + c] {
                        neighbours.append(movement)
                    }
                }
            }
            smoothed.append(Movement(dx: median(neighbours.map(\.dx)), dy: median(neighbours.map(\.dy))))
        }
        return smoothed
    }

    private static func median(_ values: [Double]) -> Double {
        if values.isEmpty { return 0 }
        let sorted = values.sorted()
        let middle = sorted.count / 2
        if sorted.count % 2 == 0 {
            return (sorted[middle - 1] + sorted[middle]) / 2
        }
        return sorted[middle]
    }
}
