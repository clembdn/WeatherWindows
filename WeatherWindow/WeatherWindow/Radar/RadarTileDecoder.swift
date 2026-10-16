//
//  RadarTileDecoder.swift
//  WeatherWindow
//
//  Created by Clement Boudon on 7/10/2026.
//

import Foundation

nonisolated struct RadarTileDecoder {
    let colorTable: RadarColorTable

    func decode(_ data: Data) throws -> (grid: RainGrid, unknownColorFraction: Double) {
        let image = try PNGImage(data: data)
        guard image.width == image.height else { throw PNGImage.DecodingError.unsupportedFormat }

        var values = [Float](repeating: RadarColorTable.noEchoDBZ, count: image.width * image.height)
        var unknownCount = 0
        var nearestByColor: [UInt32: Float] = [:]

        for index in values.indices {
            let red = image.rgba[index * 4]
            let green = image.rgba[index * 4 + 1]
            let blue = image.rgba[index * 4 + 2]
            let alpha = image.rgba[index * 4 + 3]
            if let dBZ = colorTable.dBZ(red: red, green: green, blue: blue, alpha: alpha) {
                values[index] = dBZ
                continue
            }

            unknownCount += 1
            let color = UInt32(red) << 24 | UInt32(green) << 16 | UInt32(blue) << 8 | UInt32(alpha)
            if nearestByColor[color] == nil {
                nearestByColor[color] = colorTable.nearestDBZ(red: red, green: green, blue: blue, alpha: alpha)
            }
            values[index] = nearestByColor[color] ?? RadarColorTable.noEchoDBZ
        }

        let grid = RainGrid(size: image.width, values: values)
        return (grid, Double(unknownCount) / Double(values.count))
    }
}
