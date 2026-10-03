import CZlib
import Foundation

/// An 8-bit RGBA PNG decoded without CoreGraphics, so the same code runs on Linux and iOS.
public struct PNGImage: Sendable {
    public let width: Int
    public let height: Int
    /// Pixels row by row, four straight (not premultiplied) bytes each: red, green, blue, alpha.
    public let rgba: [UInt8]

    /// Why a PNG could not be decoded.
    public enum DecodingError: LocalizedError, Equatable {
        case notPNG
        case unsupportedFormat
        case corruptData

        public var errorDescription: String? {
            switch self {
            case .notPNG: "The radar image is not a PNG file."
            case .unsupportedFormat: "The radar image uses a PNG format WeatherWindow cannot read."
            case .corruptData: "The radar image is damaged or was re-compressed."
            }
        }
    }

    private static let signature: [UInt8] = [137, 80, 78, 71, 13, 10, 26, 10]
    private static let bytesPerPixel = 4

    public init(data: Data) throws {
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
        var output = [UInt8](repeating: 0, count: expectedCount)
        var outputCount = uLongf(expectedCount)
        let status = output.withUnsafeMutableBufferPointer { destination in
            compressed.withUnsafeBufferPointer { source in
                uncompress(destination.baseAddress, &outputCount, source.baseAddress, uLong(source.count))
            }
        }
        guard status == Z_OK, Int(outputCount) == expectedCount else { throw DecodingError.corruptData }
        return output
    }

    /// Undoes the per-row PNG filters (None, Sub, Up, Average, Paeth).
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
