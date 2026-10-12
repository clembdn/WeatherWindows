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
        var unknownCount = 0
        // Searching the closest colour is slow, so each unknown colour is searched only once.
        var nearestByColor: [UInt32: Float] = [:]

        for index in values.indices {
            let red = image.rgba[index * 4]
            let green = image.rgba[index * 4 + 1]
            let blue = image.rgba[index * 4 + 2]
            let alpha = image.rgba[index * 4 + 3]
            if let dBZ = palette.dBZ(red: red, green: green, blue: blue, alpha: alpha) {
                values[index] = dBZ
                continue
            }

            unknownCount += 1
            let color = UInt32(red) << 24 | UInt32(green) << 16 | UInt32(blue) << 8 | UInt32(alpha)
            if nearestByColor[color] == nil {
                nearestByColor[color] = palette.nearestDBZ(red: red, green: green, blue: blue, alpha: alpha)
            }
            values[index] = nearestByColor[color] ?? ReflectivityPalette.noEchoDBZ
        }

        let grid = RainGrid(size: image.width, values: values)
        return (grid, Double(unknownCount) / Double(values.count))
    }
}
