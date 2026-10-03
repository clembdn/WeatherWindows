import Foundation

/// Turns a RainViewer PNG tile into a reflectivity grid.
public struct RadarTileDecoder: Sendable {
    public let palette: ReflectivityPalette

    public init(palette: ReflectivityPalette) {
        self.palette = palette
    }

    /// Decodes the tile and reports the share of pixels whose colour was not in the palette.
    public func decode(_ data: Data) throws -> (grid: RainGrid, unknownColorFraction: Double) {
        let image = try PNGImage(data: data)
        guard image.width == image.height else { throw PNGImage.DecodingError.unsupportedFormat }

        var values = [Float](repeating: ReflectivityPalette.noEchoDBZ, count: image.width * image.height)
        var nearestCache: [UInt32: Float] = [:]
        var unknownCount = 0

        for index in values.indices {
            let offset = index * 4
            let (red, green, blue, alpha) = (
                image.rgba[offset], image.rgba[offset + 1], image.rgba[offset + 2], image.rgba[offset + 3]
            )
            if let dBZ = palette.dBZ(red: red, green: green, blue: blue, alpha: alpha) {
                values[index] = dBZ
                continue
            }

            unknownCount += 1
            let key = UInt32(red) << 24 | UInt32(green) << 16 | UInt32(blue) << 8 | UInt32(alpha)
            if let cached = nearestCache[key] {
                values[index] = cached
            } else {
                let nearest = palette.nearestDBZ(red: red, green: green, blue: blue, alpha: alpha)
                nearestCache[key] = nearest
                values[index] = nearest
            }
        }

        let grid = RainGrid(size: image.width, values: values)
        return (grid, Double(unknownCount) / Double(values.count))
    }
}
