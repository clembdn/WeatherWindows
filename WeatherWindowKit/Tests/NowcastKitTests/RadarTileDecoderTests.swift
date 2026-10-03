import CZlib
import Foundation
import Testing
@testable import NowcastKit

@Test func paletteMapsUniversalBlueColors() throws {
    let palette = try ReflectivityPalette.universalBlue()

    #expect(palette.dBZ(red: 0x00, green: 0xA3, blue: 0xE0, alpha: 0xFF) == 20)
    #expect(palette.dBZ(red: 0xFF, green: 0xAA, blue: 0x00, alpha: 0xFF) == 40)
    #expect(palette.dBZ(red: 0xFF, green: 0xFF, blue: 0xFF, alpha: 0xFF) == 65)
    #expect(palette.dBZ(red: 0, green: 0, blue: 0, alpha: 0) == ReflectivityPalette.noEchoDBZ)
    #expect(palette.dBZ(red: 0x01, green: 0xA3, blue: 0xE0, alpha: 0xFF) == nil)
    #expect(palette.nearestDBZ(red: 0x01, green: 0xA3, blue: 0xE0, alpha: 0xFF) == 20)
}

/// Reference values computed independently with Pillow on the same recorded tile.
@Test func decodesRecordedTile() throws {
    let url = try #require(Bundle.module.url(
        forResource: "melbourne_1790991600", withExtension: "png", subdirectory: "Fixtures"
    ))
    let decoder = RadarTileDecoder(palette: try .universalBlue())
    let (grid, unknownColorFraction) = try decoder.decode(Data(contentsOf: url))

    #expect(grid.size == 512)
    #expect(unknownColorFraction == 0)
    #expect(grid.values.filter { $0 >= 20 }.count == 30_638)
    #expect(grid.values.reduce(0, +) == -2_428_600)
    #expect(grid[278, 277] == 13)
    #expect(grid[100, 100] == ReflectivityPalette.noEchoDBZ)
    #expect(grid[400, 300] == 8)
}

@Test func undoesEveryRowFilter() throws {
    let rows: [[UInt8]] = (0..<5).map { row in
        (0..<8).map { UInt8(truncatingIfNeeded: row * 53 + $0 * 31 + ($0 % 3) * 97) }
    }
    let png = try makePNG(width: 2, rows: rows, filters: [0, 1, 2, 3, 4])

    let image = try PNGImage(data: png)

    #expect(image.width == 2)
    #expect(image.height == 5)
    #expect(image.rgba == rows.flatMap { $0 })
}

@Test func rejectsDataThatIsNotPNG() {
    #expect(throws: PNGImage.DecodingError.notPNG) {
        try PNGImage(data: Data("not an image".utf8))
    }
}

/// Builds a minimal RGBA PNG, applying the given filter to each row.
private func makePNG(width: Int, rows: [[UInt8]], filters: [UInt8]) throws -> Data {
    var filtered: [UInt8] = []
    for (index, row) in rows.enumerated() {
        let previous = index > 0 ? rows[index - 1] : [UInt8](repeating: 0, count: row.count)
        filtered.append(filters[index])
        for i in row.indices {
            let left = i >= 4 ? Int(row[i - 4]) : 0
            let up = Int(previous[i])
            let upLeft = i >= 4 ? Int(previous[i - 4]) : 0
            let predictor: Int = switch filters[index] {
            case 1: left
            case 2: up
            case 3: (left + up) / 2
            case 4: paeth(left, up, upLeft)
            default: 0
            }
            filtered.append(row[i] &- UInt8(truncatingIfNeeded: predictor))
        }
    }

    var compressedCount = compressBound(uLong(filtered.count))
    var compressed = [UInt8](repeating: 0, count: Int(compressedCount))
    let status = compress(&compressed, &compressedCount, filtered, uLong(filtered.count))
    try #require(status == Z_OK)

    func chunk(_ type: String, _ body: [UInt8]) -> [UInt8] {
        bigEndian(body.count) + Array(type.utf8) + body + [0, 0, 0, 0]
    }
    let header = bigEndian(width) + bigEndian(rows.count) + [8, 6, 0, 0, 0]
    let bytes: [UInt8] = [137, 80, 78, 71, 13, 10, 26, 10]
        + chunk("IHDR", header)
        + chunk("IDAT", Array(compressed.prefix(Int(compressedCount))))
        + chunk("IEND", [])
    return Data(bytes)
}

private func bigEndian(_ value: Int) -> [UInt8] {
    [24, 16, 8, 0].map { UInt8(truncatingIfNeeded: value >> $0) }
}

private func paeth(_ left: Int, _ up: Int, _ upLeft: Int) -> Int {
    let estimate = left + up - upLeft
    let (a, b, c) = (abs(estimate - left), abs(estimate - up), abs(estimate - upLeft))
    if a <= b && a <= c { return left }
    return b <= c ? up : upLeft
}
