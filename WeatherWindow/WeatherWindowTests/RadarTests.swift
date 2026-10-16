//
//  RadarTests.swift
//  WeatherWindowTests
//
//  Created by Clement Boudon on 7/10/2026.
//

import Foundation
import Testing
@testable import WeatherWindow

@Test func georeferencesMelbourneCBD() {
    let pixelConverter = PixelConverter()
    let cbd = GeoPoint(latitude: -37.8136, longitude: 144.9631)

    let pixel = pixelConverter.pixel(for: cbd)

    #expect(abs(pixel.x - 278) <= 1)
    #expect(abs(pixel.y - 277) <= 1)
}

@Test func pixelRoundTripsToTheSamePlace() {
    let pixelConverter = PixelConverter()
    let cbd = GeoPoint(latitude: -37.8136, longitude: 144.9631)

    let pixel = pixelConverter.pixel(for: cbd)
    let back = pixelConverter.point(forPixelX: pixel.x, y: pixel.y)

    #expect(abs(back.latitude - cbd.latitude) < 1e-9)
    #expect(abs(back.longitude - cbd.longitude) < 1e-9)
}

@Test func recoversUniformShift() {
    let frames = (0..<4).map { step in
        frame(discAt: (x: 200 + 10 * Double(step), y: 250 + 4 * Double(step)), minutes: 10 * step)
    }

    let motion = MotionFinder().estimate(from: frames)
    let atCentre = motion.movement(atX: 230, y: 262)

    #expect(!motion.isGlobal)
    #expect(abs(atCentre.dx - 10) <= 1)
    #expect(abs(atCentre.dy - 4) <= 1)
}

@Test func zeroMotionKeepsFrame() {
    let last = frame(discAt: (x: 256, y: 256), minutes: 0)
    let still = RainMotion.uniform(.zero, gridSize: 512, blockSize: 16)

    let forecast = RainMover.forecast(from: last, motion: still, minutes: 1...30)

    #expect(forecast.count == 30)
    #expect(forecast.allSatisfy { $0.grid == last.grid })
    #expect(forecast.last?.time == last.time.addingTimeInterval(30 * 60))
}

@Test func predictsMovingDisc() throws {
    let frames = (0..<4).map { step in frame(discAt: (x: 150 + 10 * Double(step), y: 250), minutes: 10 * step) }
    let motion = MotionFinder().estimate(from: frames)

    let forecast = RainMover.forecast(from: frames[3], motion: motion, minutes: 20...20)
    let centre = try #require(rainCentre(forecast[0].grid))

    #expect(abs(centre.x - 200) <= 1)
    #expect(abs(centre.y - 250) <= 1)
}

@Test func fallsBackToGlobalVector() {
    let frames = (0..<3).map { step in
        frame(discAt: (x: 300 + 6 * Double(step), y: 300 - 3 * Double(step)), radius: 7, minutes: 10 * step)
    }

    let motion = MotionFinder().estimate(from: frames)

    #expect(motion.isGlobal)
    #expect(Set(motion.movements).count == 1)
    #expect(abs(motion.movements[0].dx - 6) <= 1)
    #expect(abs(motion.movements[0].dy + 3) <= 1)
}

@Test func csiBounds() throws {
    let grid = frame(discAt: (x: 100, y: 100), minutes: 0).grid
    let elsewhere = frame(discAt: (x: 400, y: 400), minutes: 0).grid

    #expect(NowcastScorer.counts(forecast: grid, observed: grid).criticalSuccessIndex == 1)
    #expect(NowcastScorer.counts(forecast: grid, observed: elsewhere).criticalSuccessIndex == 0)
    #expect(NowcastScorer.counts(forecast: .empty(size: 512), observed: .empty(size: 512)).criticalSuccessIndex == nil)
}

private nonisolated struct ConstantRain: RainForecast {
    let weight: Double
    func weight(at point: GeoPoint, time: Date) -> Double { weight }
}

private func frame(discAt centre: (x: Double, y: Double), radius: Double = 40, minutes: Int) -> RadarFrame {
    var grid = RainGrid.empty(size: 512)
    for y in 0..<512 {
        for x in 0..<512 {
            let distance = ((Double(x) - centre.x) * (Double(x) - centre.x) + (Double(y) - centre.y) * (Double(y) - centre.y)).squareRoot()
            if distance <= radius {
                grid[x, y] = Float(50 - 0.6 * distance)
            }
        }
    }
    return RadarFrame(grid: grid, time: Date(timeIntervalSince1970: 1_790_985_600 + TimeInterval(minutes * 60)))
}

private func rainCentre(_ grid: RainGrid) -> (x: Double, y: Double)? {
    var total = 0.0, sumX = 0.0, sumY = 0.0
    for y in 0..<grid.size {
        for x in 0..<grid.size where grid[x, y] >= 20 {
            let weight = Double(grid[x, y])
            total += weight
            sumX += weight * Double(x)
            sumY += weight * Double(y)
        }
    }
    return total > 0 ? (sumX / total, sumY / total) : nil
}

@Test func beatsPersistenceOnRecordedDay() async throws {
    let lastRecordedFrame = Date(timeIntervalSince1970: 1_791_005_400)
    let frames = try await recordedRadar().frames(upTo: lastRecordedFrame, count: 200)
    let cbd = (x: 278, y: 277)
    let region = PixelBox(minX: cbd.x - 96, minY: cbd.y - 96, maxX: cbd.x + 96, maxY: cbd.y + 96)

    let evaluation = NowcastScorer.evaluate(frames: frames, leadMinutes: 20, region: region)
    let nowcast = try #require(evaluation.nowcast.criticalSuccessIndex)
    let persistence = try #require(evaluation.persistence.criticalSuccessIndex)

    #expect(frames.count == 35)
    #expect(evaluation.cases >= 25)
    #expect(nowcast > persistence, "nowcast CSI \(nowcast) vs persistence \(persistence)")
}

@Test func recordedSourceReturnsFramesUpToTheReplayTime() async throws {
    let frames = try await recordedRadar().frames(upTo: Date(timeIntervalSince1970: 1_790_986_200), count: 3)

    #expect(frames.map { Int($0.time.timeIntervalSince1970) } == [1_790_985_000, 1_790_985_600, 1_790_986_200])
}

@Test func engineBuildsThirtyMinutesAroundTheRoute() async throws {
    let frames = try await recordedRadar().frames(upTo: Date(timeIntervalSince1970: 1_790_989_800), count: 4)
    let cbd = GeoPoint(latitude: -37.8136, longitude: 144.9631)

    let outcome = NowcastMaker.make(frames: frames, around: [cbd], now: Date(timeIntervalSince1970: 1_790_990_400),
                                     fallback: ConstantRain(weight: 0))

    guard case .ready(let nowcast) = outcome else {
        Issue.record("Expected a nowcast")
        return
    }
    #expect(nowcast.forecast.count == 30)
    #expect(nowcast.region.minX <= 278 && nowcast.region.maxX >= 278)
    #expect(nowcast.lastObservation == Date(timeIntervalSince1970: 1_790_989_800))
}

@Test func engineRefusesStaleRadar() async throws {
    let frames = try await recordedRadar().frames(upTo: Date(timeIntervalSince1970: 1_790_989_800), count: 4)

    let outcome = NowcastMaker.make(frames: frames, around: [], now: Date(timeIntervalSince1970: 1_790_989_800 + 31 * 60),
                                     fallback: ConstantRain(weight: 0))

    guard case .stale(let last) = outcome else {
        Issue.record("Expected stale radar")
        return
    }
    #expect(last == Date(timeIntervalSince1970: 1_790_989_800))
}

@Test func engineIgnoresPlacesOffTheRadarTile() async throws {
    let frames = try await recordedRadar().frames(upTo: Date(timeIntervalSince1970: 1_790_989_800), count: 4)
    let sydney = GeoPoint(latitude: -33.8688, longitude: 151.2093)

    let outcome = NowcastMaker.make(frames: frames, around: [sydney], now: Date(timeIntervalSince1970: 1_790_990_400),
                                     fallback: ConstantRain(weight: 0))

    guard case .outsideRadar = outcome else {
        Issue.record("Expected the route to be outside the radar tile")
        return
    }
}

private func recordedRadar() throws -> RecordedRadar {
    let files = Bundle.main.urls(forResourcesWithExtension: "tile", subdirectory: nil) ?? []
    return RecordedRadar(files: files, decoder: RadarTileDecoder(colorTable: try .universalBlue()))
}

@Test(arguments: [
    (20.0, 0.65),
    (30.0, 2.73),
    (40.0, 11.5)
])
func convertsReflectivityToRainRate(dBZ: Double, expected: Double) {
    #expect(abs(RainRate.mmPerHour(dBZ: dBZ) - expected) <= 0.05)
}
