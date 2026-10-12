import Foundation

/// Measures how rain moved between radar images by matching small blocks (like following groups in a crowd).
public struct BlockMatchingEstimator: Sendable {
    public var blockSize = 16
    /// Largest shift searched between two images (24 px ≈ 70 km/h over 10 minutes).
    public var searchRadius = 24
    /// Step of the coarse search; the best coarse shift is then refined pixel by pixel.
    public var coarseStep = 3
    /// A block is used only if this many of its pixels are rain.
    public var minimumRainPixels = 16
    /// Below this many usable blocks, one global vector is measured instead.
    public var minimumBlocks = 5
    /// Number of image pairs averaged, the most recent ones.
    public var pairCount = 3

    /// Reflectivity below this is treated as clear air when comparing blocks.
    public static let noiseFloor: Float = 10

    public init() {}

    /// Motion in pixels per 10 minutes from frames sorted oldest first; only blocks inside `region` are matched.
    public func estimate(from frames: [RadarFrame], region: PixelRegion? = nil) -> MotionField {
        guard frames.count >= 2, let size = frames.first?.grid.size else {
            return .uniform(.zero, gridSize: max(frames.first?.grid.size ?? 0, blockSize), blockSize: blockSize)
        }

        let columns = size / blockSize
        var sums = [MotionVector](repeating: .zero, count: columns * columns)
        var counts = [Int](repeating: 0, count: columns * columns)
        var globalVectors: [MotionVector] = []

        let firstPair = max(0, frames.count - 1 - pairCount)
        for index in firstPair..<(frames.count - 1) {
            let earlier = frames[index]
            let later = frames[index + 1]
            // Vectors are per 10 minutes, whatever the real gap between the two images.
            let scale = 600 / max(later.time.timeIntervalSince(earlier.time), 60)
            let before = Self.intensity(earlier.grid)
            let after = Self.intensity(later.grid)

            let blocks = rainyBlocks(in: earlier.grid, columns: columns, region: region)
            if blocks.count >= minimumBlocks {
                for block in blocks {
                    let area = PixelRegion(minX: block.column * blockSize, minY: block.row * blockSize,
                                           maxX: (block.column + 1) * blockSize - 1, maxY: (block.row + 1) * blockSize - 1)
                    let shift = bestShift(before, after, size: size, area: area)
                    let blockIndex = block.row * columns + block.column
                    sums[blockIndex].dx += Double(shift.dx) * scale
                    sums[blockIndex].dy += Double(shift.dy) * scale
                    counts[blockIndex] += 1
                }
            } else if !blocks.isEmpty {
                // Too few blocks to trust: match the box around all the rain as one big block.
                let area = PixelRegion(minX: blocks.map(\.column).min()! * blockSize,
                                       minY: blocks.map(\.row).min()! * blockSize,
                                       maxX: (blocks.map(\.column).max()! + 1) * blockSize - 1,
                                       maxY: (blocks.map(\.row).max()! + 1) * blockSize - 1)
                let shift = bestShift(before, after, size: size, area: area)
                globalVectors.append(MotionVector(dx: Double(shift.dx) * scale, dy: Double(shift.dy) * scale))
            } else {
                globalVectors.append(.zero)
            }
        }

        var blockVectors: [MotionVector?] = []
        for blockIndex in sums.indices {
            if counts[blockIndex] > 0 {
                let count = Double(counts[blockIndex])
                blockVectors.append(MotionVector(dx: sums[blockIndex].dx / count, dy: sums[blockIndex].dy / count))
            } else {
                blockVectors.append(nil)
            }
        }

        let usableBlocks = counts.filter { $0 > 0 }.count
        if usableBlocks < minimumBlocks {
            var global = MotionVector.zero
            if !globalVectors.isEmpty {
                let count = Double(globalVectors.count)
                global = MotionVector(dx: globalVectors.map(\.dx).reduce(0, +) / count,
                                      dy: globalVectors.map(\.dy).reduce(0, +) / count)
            }
            return .uniform(global, gridSize: size, blockSize: blockSize)
        }

        let smoothed = Self.smooth(blockVectors, columns: columns)
        return MotionField(blockSize: blockSize, columns: columns, vectors: smoothed, isGlobal: false)
    }

    /// Blocks inside the region with enough rain pixels in the earlier image.
    private func rainyBlocks(in grid: RainGrid, columns: Int, region: PixelRegion?) -> [(row: Int, column: Int)] {
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
                    for pixelX in x..<(x + blockSize) where grid[pixelX, pixelY] >= ReflectivityConverter.rainThresholdDBZ {
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

    /// The shift of `area` from `before` to `after`: coarse search, then pixel by pixel around the best one.
    private func bestShift(_ before: [Float], _ after: [Float], size: Int, area: PixelRegion) -> (dx: Int, dy: Int) {
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

    /// The shift with the smallest sum of absolute differences; on a tie, the smaller shift wins.
    private func cheapestShift(among shifts: [(dx: Int, dy: Int)], _ before: [Float], _ after: [Float],
                               size: Int, area: PixelRegion) -> (dx: Int, dy: Int) {
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

    /// Clear air and noise become 0, so only real rain drives the matching.
    private static func intensity(_ grid: RainGrid) -> [Float] {
        grid.values.map { max(0, $0 - noiseFloor) }
    }

    /// Median of each block and its valid neighbours (3 × 3); blocks without rain take the median of all blocks.
    private static func smooth(_ vectors: [MotionVector?], columns: Int) -> [MotionVector] {
        let valid = vectors.compactMap { $0 }
        let fallback = MotionVector(dx: median(valid.map(\.dx)), dy: median(valid.map(\.dy)))

        var smoothed: [MotionVector] = []
        for index in vectors.indices {
            if vectors[index] == nil {
                smoothed.append(fallback)
                continue
            }
            let row = index / columns
            let column = index % columns
            var neighbours: [MotionVector] = []
            for r in max(0, row - 1)...min(columns - 1, row + 1) {
                for c in max(0, column - 1)...min(columns - 1, column + 1) {
                    if let vector = vectors[r * columns + c] {
                        neighbours.append(vector)
                    }
                }
            }
            smoothed.append(MotionVector(dx: median(neighbours.map(\.dx)), dy: median(neighbours.map(\.dy))))
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
