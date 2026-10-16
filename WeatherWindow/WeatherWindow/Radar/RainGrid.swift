//
//  RainGrid.swift
//  WeatherWindow
//
//  Created by Clement Boudon on 7/10/2026.
//

import Foundation

nonisolated struct RainGrid: Equatable {
    let size: Int
    var values: [Float]

    init(size: Int, values: [Float]) {
        precondition(values.count == size * size, "A RainGrid needs size × size values")
        self.size = size
        self.values = values
    }

    static func empty(size: Int) -> RainGrid {
        RainGrid(size: size, values: [Float](repeating: RadarColorTable.noEchoDBZ, count: size * size))
    }

    subscript(x: Int, y: Int) -> Float {
        get { values[y * size + x] }
        set { values[y * size + x] = newValue }
    }

    func sample(x: Double, y: Double) -> Float {
        guard x >= 0, y >= 0, x <= Double(size - 1), y <= Double(size - 1) else {
            return RadarColorTable.noEchoDBZ
        }
        let x0 = Int(x), y0 = Int(y)
        let x1 = min(x0 + 1, size - 1), y1 = min(y0 + 1, size - 1)
        let fx = Float(x - Double(x0)), fy = Float(y - Double(y0))

        let top = self[x0, y0] * (1 - fx) + self[x1, y0] * fx
        let bottom = self[x0, y1] * (1 - fx) + self[x1, y1] * fx
        return top * (1 - fy) + bottom * fy
    }
}

nonisolated struct RadarFrame: Equatable {
    let grid: RainGrid
    var tile: RadarTile = .melbourne
    let time: Date
}

nonisolated struct PixelBox: Hashable {
    var minX: Int
    var minY: Int
    var maxX: Int
    var maxY: Int

    static func whole(size: Int) -> PixelBox {
        PixelBox(minX: 0, minY: 0, maxX: size - 1, maxY: size - 1)
    }

    static func around(_ pixels: [(x: Double, y: Double)], margin: Int, size: Int) -> PixelBox {
        guard let first = pixels.first else { return .whole(size: size) }
        var minX = first.x, maxX = first.x
        var minY = first.y, maxY = first.y
        for pixel in pixels {
            minX = min(minX, pixel.x)
            maxX = max(maxX, pixel.x)
            minY = min(minY, pixel.y)
            maxY = max(maxY, pixel.y)
        }
        return PixelBox(
            minX: max(0, Int(minX) - margin),
            minY: max(0, Int(minY) - margin),
            maxX: min(size - 1, Int(maxX.rounded(.up)) + margin),
            maxY: min(size - 1, Int(maxY.rounded(.up)) + margin)
        )
    }
}
