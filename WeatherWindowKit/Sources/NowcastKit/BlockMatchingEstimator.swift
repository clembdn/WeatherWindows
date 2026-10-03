import Foundation

/// Measures how rain moved between radar images by matching small blocks (like following groups in a crowd).
public struct BlockMatchingEstimator: Sendable {
    public var blockSize = 16
    /// Largest displacement searched between two images (24 px ≈ 70 km/h over 10 minutes).
    public var searchRadius = 24
    /// Coarse search step; the best coarse offset is then refined pixel by pixel.
    public var coarseStep = 3
    /// A block is used only if this many of its pixels are rain (`ReflectivityConverter.rainThresholdDBZ`).
    public var minimumRainPixels = 16
    /// Below this many usable blocks, one global vector is estimated instead.
    public var minimumBlocks = 5
    /// Image pairs averaged, newest first.
    public var pairCount = 3

    /// Reflectivity below this is treated as clear air when comparing blocks.
    public static let noiseFloor: Float = 10

    public init() {}

    /// Motion in pixels per 10 minutes, from the last `pairCount` pairs of frames (oldest first).
    /// With a region, only blocks inside it are matched (the rest take the median motion).
    public func estimate(from frames: [RadarFrame], region: PixelRegion? = nil) -> MotionField {
        let size = frames.first?.grid.size ?? 0
        let pairs = Array(zip(frames, frames.dropFirst()).suffix(pairCount))
        guard size > 0, !pairs.isEmpty else { return .uniform(.zero, gridSize: max(size, blockSize), blockSize: blockSize) }

        let columns = size / blockSize
        var sums = [MotionVector](repeating: .zero, count: columns * columns)
        var counts = [Int](repeating: 0, count: columns * columns)
        var globalVectors: [MotionVector] = []

        for (earlier, later) in pairs {
            let scale = 600 / max(later.time.timeIntervalSince(earlier.time), 60)
            let pair = estimatePair(earlier.grid, later.grid, region: region)
            switch pair {
            case .blocks(let vectors):
                for (index, vector) in vectors.enumerated() {
                    guard let vector else { continue }
                    sums[index].dx += vector.dx * scale
                    sums[index].dy += vector.dy * scale
                    counts[index] += 1
                }
            case .global(let vector):
                globalVectors.append(MotionVector(dx: vector.dx * scale, dy: vector.dy * scale))
            }
        }

        let blockVectors: [MotionVector?] = zip(sums, counts).map { sum, count in
            count > 0 ? MotionVector(dx: sum.dx / Double(count), dy: sum.dy / Double(count)) : nil
        }
        let validCount = blockVectors.count { $0 != nil }
        guard validCount >= minimumBlocks else {
            let global = globalVectors.isEmpty ? MotionVector.zero : MotionVector(
                dx: globalVectors.map(\.dx).reduce(0, +) / Double(globalVectors.count),
                dy: globalVectors.map(\.dy).reduce(0, +) / Double(globalVectors.count)
            )
            return .uniform(global, gridSize: size, blockSize: blockSize)
        }

        return MotionField(blockSize: blockSize, columns: columns,
                           vectors: Self.smooth(blockVectors, columns: columns), isGlobal: false)
    }

    // MARK: One pair

    private enum PairEstimate {
        case blocks([MotionVector?])
        case global(MotionVector)
    }

    private func estimatePair(_ earlier: RainGrid, _ later: RainGrid, region: PixelRegion?) -> PairEstimate {
        let size = earlier.size
        let columns = size / blockSize
        let before = Self.intensity(earlier)
        let after = Self.intensity(later)

        var vectors = [MotionVector?](repeating: nil, count: columns * columns)
        var rainyBlocks: [(x: Int, y: Int)] = []
        for row in 0..<columns {
            for column in 0..<columns {
                let origin = (x: column * blockSize, y: row * blockSize)
                if let region, origin.x + blockSize <= region.minX || origin.x > region.maxX
                    || origin.y + blockSize <= region.minY || origin.y > region.maxY {
                    continue
                }
                guard rainPixelCount(earlier, x: origin.x, y: origin.y, width: blockSize, height: blockSize)
                        >= minimumRainPixels else { continue }
                rainyBlocks.append(origin)
                let offset = bestOffset(before, after, size: size, x: origin.x, y: origin.y,
                                        width: blockSize, height: blockSize)
                vectors[row * columns + column] = MotionVector(dx: Double(offset.dx), dy: Double(offset.dy))
            }
        }

        if rainyBlocks.count >= minimumBlocks {
            return .blocks(vectors)
        }
        guard !rainyBlocks.isEmpty else { return .global(.zero) }

        let minX = rainyBlocks.map(\.x).min() ?? 0, maxX = (rainyBlocks.map(\.x).max() ?? 0) + blockSize
        let minY = rainyBlocks.map(\.y).min() ?? 0, maxY = (rainyBlocks.map(\.y).max() ?? 0) + blockSize
        let offset = bestOffset(before, after, size: size, x: minX, y: minY, width: maxX - minX, height: maxY - minY)
        return .global(MotionVector(dx: Double(offset.dx), dy: Double(offset.dy)))
    }

    private func rainPixelCount(_ grid: RainGrid, x: Int, y: Int, width: Int, height: Int) -> Int {
        var count = 0
        for row in y..<(y + height) {
            for column in x..<(x + width) where grid[column, row] >= ReflectivityConverter.rainThresholdDBZ {
                count += 1
            }
        }
        return count
    }

    /// Coarse then fine search for the shift with the smallest sum of absolute differences;
    /// ties go to the smaller shift.
    private func bestOffset(_ before: [Float], _ after: [Float], size: Int,
                            x: Int, y: Int, width: Int, height: Int) -> (dx: Int, dy: Int) {
        func cost(_ dx: Int, _ dy: Int) -> Float {
            var total: Float = 0
            for row in y..<(y + height) {
                let shiftedRow = row + dy
                for column in x..<(x + width) {
                    let shiftedColumn = column + dx
                    let moved: Float = shiftedRow >= 0 && shiftedRow < size && shiftedColumn >= 0 && shiftedColumn < size
                        ? after[shiftedRow * size + shiftedColumn] : 0
                    total += abs(before[row * size + column] - moved)
                }
            }
            return total
        }

        func search(_ candidates: [(Int, Int)]) -> (dx: Int, dy: Int) {
            var best = (dx: 0, dy: 0)
            var bestCost = Float.infinity
            for (dx, dy) in candidates {
                let value = cost(dx, dy)
                let isCloser = dx * dx + dy * dy < best.dx * best.dx + best.dy * best.dy
                if value < bestCost || (value == bestCost && isCloser) {
                    best = (dx, dy)
                    bestCost = value
                }
            }
            return best
        }

        let radius = searchRadius
        let coarse = stride(from: -radius, through: radius, by: coarseStep)
        let coarseBest = search(coarse.flatMap { dy in coarse.map { dx in (dx, dy) } })

        let fine = -coarseStep...coarseStep
        return search(fine.flatMap { dy in fine.compactMap { dx in
            let candidate = (coarseBest.dx + dx, coarseBest.dy + dy)
            return abs(candidate.0) <= radius && abs(candidate.1) <= radius ? candidate : nil
        } })
    }

    /// Clear air and noise become 0 so only real rain drives the matching.
    private static func intensity(_ grid: RainGrid) -> [Float] {
        grid.values.map { max(0, $0 - noiseFloor) }
    }

    /// 3 × 3 median of the valid neighbours; blocks without rain take the median of all valid vectors.
    private static func smooth(_ vectors: [MotionVector?], columns: Int) -> [MotionVector] {
        let valid = vectors.compactMap { $0 }
        let fallback = MotionVector(dx: median(valid.map(\.dx)), dy: median(valid.map(\.dy)))

        return (0..<vectors.count).map { index in
            let row = index / columns, column = index % columns
            var neighbours: [MotionVector] = []
            for r in max(0, row - 1)...min(columns - 1, row + 1) {
                for c in max(0, column - 1)...min(columns - 1, column + 1) {
                    if let vector = vectors[r * columns + c] { neighbours.append(vector) }
                }
            }
            guard vectors[index] != nil, !neighbours.isEmpty else { return fallback }
            return MotionVector(dx: median(neighbours.map(\.dx)), dy: median(neighbours.map(\.dy)))
        }
    }

    private static func median(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        let middle = sorted.count / 2
        return sorted.count.isMultiple(of: 2) ? (sorted[middle - 1] + sorted[middle]) / 2 : sorted[middle]
    }
}
