//
//  RainMover.swift
//  WeatherWindow
//
//  Created by Clement Boudon on 7/10/2026.
//

import Foundation

nonisolated enum RainMover {
    static func forecast(from frame: RadarFrame, motion: RainMotion,
                         minutes: ClosedRange<Int>, region: PixelBox? = nil) -> [RadarFrame] {
        let size = frame.grid.size
        let area = region ?? .whole(size: size)

        var frames: [RadarFrame] = []
        for minute in minutes {
            var grid = RainGrid.empty(size: size)
            let steps = Double(minute) / 10
            for y in area.minY...area.maxY {
                for x in area.minX...area.maxX {
                    let movement = motion.movement(atX: Double(x), y: Double(y))
                    grid[x, y] = frame.grid.sample(x: Double(x) - steps * movement.dx, y: Double(y) - steps * movement.dy)
                }
            }
            let time = frame.time.addingTimeInterval(TimeInterval(minute * 60))
            frames.append(RadarFrame(grid: grid, tile: frame.tile, time: time))
        }
        return frames
    }
}
