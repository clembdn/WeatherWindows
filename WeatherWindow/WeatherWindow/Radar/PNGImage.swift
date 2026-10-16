//
//  PNGImage.swift
//  WeatherWindow
//
//  Created by Clement Boudon on 7/10/2026.
//

import Foundation

nonisolated struct PNGImage {
    let width: Int
    let height: Int
    let rgba: [UInt8]

    enum DecodingError: LocalizedError, Equatable {
        case notPNG
        case unsupportedFormat
        case corruptData

        var errorDescription: String? {
            switch self {
            case .notPNG: "The radar image is not a PNG file."
            case .unsupportedFormat: "The radar image uses a PNG format WeatherWindow cannot read."
            case .corruptData: "The radar image is damaged or was re-compressed."
            }
        }
    }

    private static let signature: [UInt8] = [137, 80, 78, 71, 13, 10, 26, 10]
    private static let bytesPerPixel = 4

    init(data: Data) throws {
        let bytes = [UInt8](data)
        guard bytes.count > 8, Array(bytes[0..<8]) == Self.signature else {
            throw DecodingError.notPNG
        }

        var size: (width: Int, height: Int)?
        var compressed: [UInt8] = []
        var offset = 8
        chunks: while offset + 12 <= bytes.count {
            let length = Self.bigEndianInt(bytes, at: offset)
            let start = offset + 8
            let end = start + length
            guard end + 4 <= bytes.count else { throw DecodingError.corruptData }

            switch String(decoding: bytes[offset + 4..<start], as: UTF8.self) {
            case "IHDR":
                guard length >= 13 else { throw DecodingError.corruptData }
                let bitDepth = bytes[start + 8]
                let colorType = bytes[start + 9]
                let interlace = bytes[start + 12]
                guard bitDepth == 8, colorType == 6, interlace == 0 else {
                    throw DecodingError.unsupportedFormat
                }
                size = (Self.bigEndianInt(bytes, at: start), Self.bigEndianInt(bytes, at: start + 4))
            case "IDAT":
                compressed.append(contentsOf: bytes[start..<end])
            case "IEND":
                break chunks
            default:
                break
            }
            offset = end + 4
        }

        guard let size, size.width > 0, size.height > 0 else { throw DecodingError.corruptData }
        let rowLength = size.width * Self.bytesPerPixel
        let filtered = try Self.inflate(compressed, expectedCount: size.height * (rowLength + 1))

        width = size.width
        height = size.height
        rgba = try Self.unfilter(filtered, rowLength: rowLength, height: size.height)
    }

    private static func bigEndianInt(_ bytes: [UInt8], at offset: Int) -> Int {
        bytes[offset..<offset + 4].reduce(0) { $0 << 8 | Int($1) }
    }

    private static func inflate(_ compressed: [UInt8], expectedCount: Int) throws -> [UInt8] {
        guard compressed.count > 6 else { throw DecodingError.corruptData }
        let deflate = Data(compressed[2..<(compressed.count - 4)])
        guard let output = try? (deflate as NSData).decompressed(using: .zlib) as Data,
              output.count == expectedCount else {
            throw DecodingError.corruptData
        }
        return [UInt8](output)
    }

    private static func unfilter(_ filtered: [UInt8], rowLength: Int, height: Int) throws -> [UInt8] {
        var pixels = [UInt8](repeating: 0, count: rowLength * height)
        let step = bytesPerPixel

        for row in 0..<height {
            let filter = filtered[row * (rowLength + 1)]
            let source = row * (rowLength + 1) + 1
            let target = row * rowLength

            for i in 0..<rowLength {
                let raw = filtered[source + i]
                let left = i >= step ? Int(pixels[target + i - step]) : 0
                let up = row > 0 ? Int(pixels[target + i - rowLength]) : 0
                let upLeft = i >= step && row > 0 ? Int(pixels[target + i - rowLength - step]) : 0

                let predictor: Int
                switch filter {
                case 0: predictor = 0
                case 1: predictor = left
                case 2: predictor = up
                case 3: predictor = (left + up) / 2
                case 4: predictor = paeth(left, up, upLeft)
                default: throw DecodingError.corruptData
                }
                pixels[target + i] = raw &+ UInt8(truncatingIfNeeded: predictor)
            }
        }
        return pixels
    }

    private static func paeth(_ left: Int, _ up: Int, _ upLeft: Int) -> Int {
        let estimate = left + up - upLeft
        let distanceLeft = abs(estimate - left)
        let distanceUp = abs(estimate - up)
        let distanceUpLeft = abs(estimate - upLeft)
        if distanceLeft <= distanceUp && distanceLeft <= distanceUpLeft { return left }
        return distanceUp <= distanceUpLeft ? up : upLeft
    }
}
