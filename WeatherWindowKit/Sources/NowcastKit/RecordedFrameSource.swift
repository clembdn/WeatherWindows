import Foundation

/// Where radar frames come from: live RainViewer in the app, a recorded session for replay and tests.
public protocol RadarFrameSource: Sendable {
    /// Up to `count` frames captured at or before `time`, oldest first.
    func frames(upTo time: Date, count: Int) async throws -> [RadarFrame]
}

/// Recorded PNG tiles whose file names contain their Unix capture time (`1790989200.png`, `replay-1790989200.tile`).
/// Tiles shipped inside an iOS app use the `.tile` extension so Xcode copies them untouched instead of
/// converting them to Apple's premultiplied CgBI PNG variant.
public struct RecordedFrameSource: RadarFrameSource {
    public static let fileExtensions: Set<String> = ["png", "tile"]

    public let files: [URL]
    public let decoder: RadarTileDecoder

    public init(files: [URL], decoder: RadarTileDecoder) {
        self.files = files.filter { Self.fileExtensions.contains($0.pathExtension) && Self.captureTime(of: $0) != nil }
        self.decoder = decoder
    }

    /// Every tile of a folder, as written by `ww record`.
    public init(folder: URL, decoder: RadarTileDecoder) throws {
        self.init(files: try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil),
                  decoder: decoder)
    }

    /// Capture times available, oldest first.
    public var availableTimes: [Date] {
        files.compactMap(Self.captureTime(of:)).sorted()
    }

    public func frames(upTo time: Date, count: Int) async throws -> [RadarFrame] {
        let chosen = files
            .compactMap { file in Self.captureTime(of: file).map { (file: file, time: $0) } }
            .filter { $0.time <= time }
            .sorted { $0.time < $1.time }
            .suffix(count)
        return try chosen.map { RadarFrame(grid: try decoder.decode(Data(contentsOf: $0.file)).grid, time: $0.time) }
    }

    private static func captureTime(of file: URL) -> Date? {
        let digits = file.deletingPathExtension().lastPathComponent.filter(\.isNumber)
        return TimeInterval(digits).map { Date(timeIntervalSince1970: $0) }
    }
}
