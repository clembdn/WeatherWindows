//
//  RadarTileDecoderTests.swift
//  WeatherWindowTests
//
//  Created by Clement Boudon on 7/10/2026.
//

import Foundation
import Testing
@testable import WeatherWindow

@Test func paletteMapsUniversalBlueColors() throws {
    let colorTable = try RadarColorTable.universalBlue()

    #expect(colorTable.dBZ(red: 0x00, green: 0xA3, blue: 0xE0, alpha: 0xFF) == 20)
    #expect(colorTable.dBZ(red: 0xFF, green: 0xAA, blue: 0x00, alpha: 0xFF) == 40)
    #expect(colorTable.dBZ(red: 0xFF, green: 0xFF, blue: 0xFF, alpha: 0xFF) == 65)
    #expect(colorTable.dBZ(red: 0, green: 0, blue: 0, alpha: 0) == RadarColorTable.noEchoDBZ)
    #expect(colorTable.dBZ(red: 0x01, green: 0xA3, blue: 0xE0, alpha: 0xFF) == nil)
    #expect(colorTable.nearestDBZ(red: 0x01, green: 0xA3, blue: 0xE0, alpha: 0xFF) == 20)
}

@Test func decodesRecordedTile() throws {
    let url = try #require(Bundle.main.url(forResource: "replay-1790991600", withExtension: "tile"))
    let decoder = RadarTileDecoder(colorTable: try .universalBlue())
    let (grid, unknownColorFraction) = try decoder.decode(Data(contentsOf: url))

    #expect(grid.size == 512)
    #expect(unknownColorFraction == 0)
    #expect(grid.values.filter { $0 >= 20 }.count == 30_638)
    #expect(grid.values.reduce(0, +) == -2_428_600)
    #expect(grid[278, 277] == 13)
    #expect(grid[100, 100] == RadarColorTable.noEchoDBZ)
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

@Test func buildsTileURL() throws {
    let list = try JSONDecoder().decode(RainViewerResponse.self, from: fixture("weather_maps"))
    let frame = try #require(list.radar.past.first)

    let url = RainViewerService.tileURL(host: list.host, path: frame.path)

    #expect(url?.absoluteString == "https://tilecache.rainviewer.com/v2/radar/d39cd0573090/512/7/115/78/2/0_0.png")
}

@Test func rejectsDataThatIsNotPNG() {
    #expect(throws: PNGImage.DecodingError.notPNG) {
        try PNGImage(data: Data("not an image".utf8))
    }
}

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

    let deflate = try (Data(filtered) as NSData).compressed(using: .zlib) as Data
    let compressed: [UInt8] = [0x78, 0x9C] + [UInt8](deflate) + [0, 0, 0, 0]

    func chunk(_ type: String, _ body: [UInt8]) -> [UInt8] {
        bigEndian(body.count) + Array(type.utf8) + body + [0, 0, 0, 0]
    }
    let header = bigEndian(width) + bigEndian(rows.count) + [8, 6, 0, 0, 0]
    let bytes: [UInt8] = [137, 80, 78, 71, 13, 10, 26, 10]
        + chunk("IHDR", header)
        + chunk("IDAT", compressed)
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
