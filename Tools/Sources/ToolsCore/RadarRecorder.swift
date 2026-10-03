import ForecastKit
import Foundation
import NowcastKit
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Downloads the RainViewer frames that are not on disk yet and measures their rain.
public struct RadarRecorder: Sendable {
    public let store: RecordingStore
    public let decoder: RadarTileDecoder

    public init(store: RecordingStore, decoder: RadarTileDecoder) {
        self.store = store
        self.decoder = decoder
    }

    public struct Summary: Sendable {
        public var saved = 0
        public var skipped = 0
        public var failures: [String] = []
        public var measured = 0
    }

    /// One pass: at most 1 + 13 requests, well under RainViewer's 100 per minute.
    public func record() async throws -> Summary {
        var summary = Summary()
        let maps = try JSONDecoder().decode(RainViewerMaps.self, from: try await fetch(RainViewerMaps.endpoint))

        for frame in maps.radar.past {
            if store.hasFrame(at: frame.time) {
                summary.skipped += 1
                continue
            }
            guard let url = maps.tileURL(for: frame) else {
                summary.failures.append("No tile URL for frame \(Int(frame.time.timeIntervalSince1970))")
                continue
            }

            do {
                let png = try await fetch(url)
                let downloadedAt = Int(Date().timeIntervalSince1970)
                var record = FrameRecord(
                    downloadedAt: downloadedAt,
                    delaySeconds: downloadedAt - Int(frame.time.timeIntervalSince1970),
                    url: url.absoluteString
                )
                record.measure(try decoder.decode(png).grid)
                try store.save(png: png, at: frame.time, record: record)
                summary.saved += 1
            } catch ToolError.httpStatus(429) {
                summary.failures.append("RainViewer rate limit reached, stopping this pass")
                break
            } catch {
                summary.failures.append("Frame \(Int(frame.time.timeIntervalSince1970)): \(error)")
            }
        }

        summary.measured = try measureMissingStatistics()
        return summary
    }

    /// Fills in rain statistics for frames added without them (older recordings, synced backups).
    public func measureMissingStatistics() throws -> Int {
        var measured = 0
        for day in store.days() {
            var index = store.loadIndex(day: day)
            var changed = false
            for time in store.frameTimes(day: day) where index[String(time)]?.hasStatistics != true {
                let png = try Data(contentsOf: store.frameURL(day: day, time: time))
                var record = index[String(time)] ?? FrameRecord()
                record.measure(try decoder.decode(png).grid)
                index[String(time)] = record
                changed = true
                measured += 1
            }
            if changed { try store.saveIndex(index, day: day) }
        }
        return measured
    }

    private func fetch(_ url: URL) async throws -> Data {
        var request = URLRequest(url: url, timeoutInterval: 20)
        request.setValue("WeatherWindow-FIT3178-recorder/1.0", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ToolError.invalidResponse }
        guard (200...299).contains(http.statusCode) else { throw ToolError.httpStatus(http.statusCode) }
        return data
    }
}

/// Failures reported by the command-line tools.
public enum ToolError: Error, Equatable, CustomStringConvertible {
    case invalidResponse
    case httpStatus(Int)
    case commandFailed(String)
    case repositoryNotFound

    public var description: String {
        switch self {
        case .invalidResponse: "The server returned an invalid response."
        case .httpStatus(let code): "The server returned HTTP \(code)."
        case .commandFailed(let command): "Command failed: \(command)"
        case .repositoryNotFound: "Run ww from inside the WeatherWindows repository."
        }
    }
}
