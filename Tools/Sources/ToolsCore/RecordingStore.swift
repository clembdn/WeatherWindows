import Foundation
import NowcastKit

/// Provenance and rain statistics of one recorded radar frame, as stored in a day's `index.json`.
public struct FrameRecord: Codable, Equatable, Sendable {
    public var downloadedAt: Int?
    public var delaySeconds: Int?
    public var url: String?
    public var rainFraction: Double?
    public var cbdRainFraction: Double?
    public var maxDBZ: Float?

    private enum CodingKeys: String, CodingKey {
        case downloadedAt = "downloaded_at"
        case delaySeconds = "delay_seconds"
        case url
        case rainFraction = "rain_fraction"
        case cbdRainFraction = "cbd_rain_fraction"
        case maxDBZ = "max_dbz"
    }

    public init(downloadedAt: Int? = nil, delaySeconds: Int? = nil, url: String? = nil) {
        self.downloadedAt = downloadedAt
        self.delaySeconds = delaySeconds
        self.url = url
    }

    public var hasStatistics: Bool {
        rainFraction != nil && cbdRainFraction != nil && maxDBZ != nil
    }

    /// Reflectivity from which a pixel counts as rain (≈ 0.65 mm/h).
    public static let rainThresholdDBZ: Float = 20
    /// Melbourne CBD in the zoom 7 tile, and a ≈ 10 km radius around it.
    public static let cbdPixel = (x: 278, y: 277)
    public static let cbdRadius = 20

    public mutating func measure(_ grid: RainGrid) {
        let threshold = Self.rainThresholdDBZ
        rainFraction = Double(grid.values.count { $0 >= threshold }) / Double(grid.values.count)
        maxDBZ = grid.values.max()

        let xs = max(0, Self.cbdPixel.x - Self.cbdRadius)...min(grid.size - 1, Self.cbdPixel.x + Self.cbdRadius)
        let ys = max(0, Self.cbdPixel.y - Self.cbdRadius)...min(grid.size - 1, Self.cbdPixel.y + Self.cbdRadius)
        let window = ys.flatMap { y in xs.map { x in grid[x, y] } }
        cbdRainFraction = Double(window.count { $0 >= threshold }) / Double(window.count)
    }
}

/// Folder of recorded frames: `<root>/<Melbourne day>/<unix time>.png`, plus one `index.json` per day.
public struct RecordingStore: Sendable {
    public let root: URL
    public static let timeZone = TimeZone(identifier: "Australia/Melbourne") ?? .gmt

    public init(root: URL) {
        self.root = root
    }

    public func dayName(for time: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = Self.timeZone
        let parts = calendar.dateComponents([.year, .month, .day], from: time)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    public func frameURL(day: String, time: Int) -> URL {
        root.appending(path: day).appending(path: "\(time).png")
    }

    public func hasFrame(at time: Date) -> Bool {
        let day = dayName(for: time)
        return FileManager.default.fileExists(atPath: frameURL(day: day, time: Int(time.timeIntervalSince1970)).path)
    }

    public func save(png: Data, at time: Date, record: FrameRecord) throws {
        let day = dayName(for: time)
        let seconds = Int(time.timeIntervalSince1970)
        try FileManager.default.createDirectory(at: root.appending(path: day), withIntermediateDirectories: true)
        try png.write(to: frameURL(day: day, time: seconds), options: .atomic)

        var index = loadIndex(day: day)
        index[String(seconds)] = record
        try saveIndex(index, day: day)
    }

    /// Recorded days, oldest first.
    public func days() -> [String] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: root.path)) ?? []
        return names.filter { $0.wholeMatch(of: /\d{4}-\d{2}-\d{2}/) != nil }.sorted()
    }

    /// Capture times of the frames recorded on a day, oldest first.
    public func frameTimes(day: String) -> [Int] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: root.appending(path: day).path)) ?? []
        return names.compactMap { name in
            name.hasSuffix(".png") ? Int(name.dropLast(4)) : nil
        }.sorted()
    }

    public func loadIndex(day: String) -> [String: FrameRecord] {
        guard let data = try? Data(contentsOf: indexURL(day: day)) else { return [:] }
        return (try? JSONDecoder().decode([String: FrameRecord].self, from: data)) ?? [:]
    }

    public func saveIndex(_ index: [String: FrameRecord], day: String) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(index).write(to: indexURL(day: day), options: .atomic)
    }

    private func indexURL(day: String) -> URL {
        root.appending(path: day).appending(path: "index.json")
    }
}
