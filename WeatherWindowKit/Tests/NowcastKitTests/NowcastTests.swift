import Foundation
import Testing
import WeatherWindowCore
@testable import NowcastKit

// MARK: - Spec tests

@Test func georeferencesMelbourneCBD() {
    let georeference = Georeference()
    let cbd = GeoPoint(latitude: -37.8136, longitude: 144.9631)

    let pixel = georeference.pixel(for: cbd)
    let back = georeference.point(atPixelX: pixel.x, y: pixel.y)

    #expect(abs(pixel.x - 278) <= 1)
    #expect(abs(pixel.y - 277) <= 1)
    #expect(abs(back.latitude - cbd.latitude) < 1e-9)
    #expect(abs(back.longitude - cbd.longitude) < 1e-9)
    #expect(abs(georeference.metresPerPixel(atLatitude: cbd.latitude) - 483) < 2)
}

@Test func recoversUniformShift() {
    let frames = (0..<4).map { step in
        frame(discAt: (x: 200 + 10 * Double(step), y: 250 + 4 * Double(step)), minutes: 10 * step)
    }

    let motion = BlockMatchingEstimator().estimate(from: frames)
    let atCentre = motion.vector(atX: 230, y: 262)

    #expect(!motion.isGlobal)
    #expect(abs(atCentre.dx - 10) <= 1)
    #expect(abs(atCentre.dy - 4) <= 1)
}

@Test func zeroMotionKeepsFrame() {
    let last = frame(discAt: (x: 256, y: 256), minutes: 0)
    let still = MotionField.uniform(.zero, gridSize: 512, blockSize: 16)

    let forecast = Advector.forecast(from: last, motion: still, minutes: 1...30)

    #expect(forecast.count == 30)
    #expect(forecast.allSatisfy { $0.grid == last.grid })
    #expect(forecast.last?.time == last.time.addingTimeInterval(30 * 60))
}

@Test func predictsMovingDisc() throws {
    let frames = (0..<4).map { step in frame(discAt: (x: 150 + 10 * Double(step), y: 250), minutes: 10 * step) }
    let motion = BlockMatchingEstimator().estimate(from: frames)

    let forecast = Advector.forecast(from: frames[3], motion: motion, minutes: 20...20)
    let centre = try #require(rainCentre(forecast[0].grid))

    #expect(abs(centre.x - 200) <= 1)
    #expect(abs(centre.y - 250) <= 1)
}

@Test func fallsBackToGlobalVector() {
    let frames = (0..<3).map { step in
        frame(discAt: (x: 300 + 6 * Double(step), y: 300 - 3 * Double(step)), radius: 7, minutes: 10 * step)
    }

    let motion = BlockMatchingEstimator().estimate(from: frames)

    #expect(motion.isGlobal)
    #expect(Set(motion.vectors).count == 1)
    #expect(abs(motion.meanVector.dx - 6) <= 1)
    #expect(abs(motion.meanVector.dy + 3) <= 1)
}

@Test func csiBounds() throws {
    let grid = frame(discAt: (x: 100, y: 100), minutes: 0).grid
    let elsewhere = frame(discAt: (x: 400, y: 400), minutes: 0).grid

    #expect(Verifier.counts(forecast: grid, observed: grid).criticalSuccessIndex == 1)
    #expect(Verifier.counts(forecast: grid, observed: elsewhere).criticalSuccessIndex == 0)
    #expect(Verifier.counts(forecast: .empty(size: 512), observed: .empty(size: 512)).criticalSuccessIndex == nil)
}

// MARK: - Blending with the forecast

@Test func nowcastFadesIntoTheHourlyForecast() {
    let last = frame(discAt: (x: 278, y: 277), minutes: 0)
    let field = NowcastRainField(frames: [last], lastObservation: last.time, fallback: ConstantRain(weight: 0))
    let cbd = GeoPoint(latitude: -37.8136, longitude: 144.9631)

    #expect(field.weight(at: cbd, time: last.time) == 1)
    #expect(abs(field.nowcastShare(at: last.time.addingTimeInterval(15 * 60)) - 0.5) < 1e-9)
    #expect(field.weight(at: cbd, time: last.time.addingTimeInterval(30 * 60)) == 0)
}

@Test func noEchoIsDry() {
    #expect(ReflectivityConverter.rainWeight(dBZ: Double(ReflectivityPalette.noEchoDBZ)) == 0)
    #expect(ReflectivityConverter.rainWeight(dBZ: 40) == 1)
}

// MARK: - Helpers

private struct ConstantRain: RainField {
    let weight: Double
    func weight(at point: GeoPoint, time: Date) -> Double { weight }
}

/// A rain cell: 50 dBZ at the centre, fading 0.6 dBZ per pixel, so every shift looks different.
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

/// Reflectivity-weighted centre of the rain (≥ 20 dBZ).
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

// MARK: - Recorded day

/// Every frame recorded over Melbourne on 3 October 2026 (showers moving across the CBD), scored like
/// `./ww verify`. A 10-frame excerpt alone does not show the gain: it holds over the day, not every hour.
@Test func beatsPersistenceOnRecordedDay() throws {
    let decoder = RadarTileDecoder(palette: try .universalBlue())
    let folder = try #require(Bundle.module.url(forResource: "recorded", withExtension: nil, subdirectory: "Fixtures"))
    let files = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
        .filter { $0.pathExtension == "png" }
    let frames = try files.map { file in
        let seconds = try #require(TimeInterval(file.deletingPathExtension().lastPathComponent))
        return RadarFrame(grid: try decoder.decode(Data(contentsOf: file)).grid, time: Date(timeIntervalSince1970: seconds))
    }
    let cbd = (x: 278, y: 277)
    let region = PixelRegion(minX: cbd.x - 96, minY: cbd.y - 96, maxX: cbd.x + 96, maxY: cbd.y + 96)

    let evaluation = Verifier.evaluate(frames: frames, leadMinutes: 20, region: region)
    let nowcast = try #require(evaluation.nowcast.criticalSuccessIndex)
    let persistence = try #require(evaluation.persistence.criticalSuccessIndex)

    #expect(frames.count == 35)
    #expect(evaluation.cases >= 25)
    #expect(nowcast > persistence, "nowcast CSI \(nowcast) vs persistence \(persistence)")
}
