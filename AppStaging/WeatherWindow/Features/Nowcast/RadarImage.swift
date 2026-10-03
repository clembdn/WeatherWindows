import CoreGraphics
import Foundation
import NowcastKit

/// Colours for radar reflectivity, from light drizzle (pale blue) to storms (red).
nonisolated enum RadarColor {
    /// Red, green, blue and alpha (0...255), straight alpha; clear air is fully transparent.
    static func rgba(dBZ: Float) -> (UInt8, UInt8, UInt8, UInt8) {
        switch dBZ {
        case ..<10: (0, 0, 0, 0)
        case ..<20: (136, 221, 238, 140)
        case ..<30: (0, 163, 224, 190)
        case ..<40: (0, 85, 136, 220)
        case ..<50: (255, 170, 0, 230)
        default: (200, 0, 0, 240)
        }
    }

    /// Plain words for the rain at a point, for VoiceOver and labels.
    static func description(dBZ: Float) -> String {
        switch dBZ {
        case ..<20: "dry"
        case ..<30: "light rain"
        case ..<40: "moderate rain"
        default: "heavy rain"
        }
    }

    /// The region of a grid as an image, faded by `opacity` (predicted frames fade as lead time grows).
    static func image(of grid: RainGrid, region: PixelRegion, opacity: Double) -> CGImage? {
        let width = region.maxX - region.minX + 1
        let height = region.maxY - region.minY + 1
        var bytes = [UInt8](repeating: 0, count: width * height * 4)

        for y in 0..<height {
            for x in 0..<width {
                let (red, green, blue, alpha) = rgba(dBZ: grid[region.minX + x, region.minY + y])
                let a = Double(alpha) * opacity / 255
                let offset = (y * width + x) * 4
                bytes[offset] = UInt8(Double(red) * a)
                bytes[offset + 1] = UInt8(Double(green) * a)
                bytes[offset + 2] = UInt8(Double(blue) * a)
                bytes[offset + 3] = UInt8(a * 255)
            }
        }

        guard let provider = CGDataProvider(data: Data(bytes) as CFData) else { return nil }
        return CGImage(
            width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent
        )
    }
}
