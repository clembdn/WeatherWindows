import ForecastKit
import Foundation
import NowcastKit
import OSLog

/// Live RainViewer frames over Melbourne, downloaded in parallel and cached by capture time.
actor LiveRainViewerSource: RadarFrameSource {
    static let shared = LiveRainViewerSource()

    private let session: URLSession
    private var cache: [Date: RadarFrame] = [:]

    init(session: URLSession = .shared) {
        self.session = session
    }

    func frames(upTo time: Date, count: Int) async throws -> [RadarFrame] {
        let decoder = RadarTileDecoder(palette: try .universalBlue())
        let maps = try JSONDecoder().decode(RainViewerMaps.self, from: try await Self.download(RainViewerMaps.endpoint, session: session))
        let wanted = Array(maps.radar.past.filter { $0.time <= time }.suffix(count))
        let missing = wanted.filter { cache[$0.time] == nil }

        let session = session
        let downloaded = try await withThrowingTaskGroup(of: RadarFrame.self) { group in
            for frame in missing {
                guard let url = maps.tileURL(for: frame) else { continue }
                group.addTask {
                    let png = try await Self.download(url, session: session)
                    return RadarFrame(grid: try decoder.decode(png).grid, time: frame.time)
                }
            }
            var frames: [RadarFrame] = []
            for try await frame in group { frames.append(frame) }
            return frames
        }

        for frame in downloaded { cache[frame.time] = frame }
        let oldest = wanted.first?.time ?? time
        cache = cache.filter { $0.key >= oldest }
        return wanted.compactMap { cache[$0.time] }
    }

    private static func download(_ url: URL, session: URLSession) async throws -> Data {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(from: url)
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch {
            Logger.network.error("RainViewer request failed: \(error.localizedDescription, privacy: .public)")
            throw ServiceError(error)
        }
        guard let http = response as? HTTPURLResponse else { throw ServiceError.invalidResponse }
        guard (200...299).contains(http.statusCode) else {
            throw http.statusCode == 429 ? ServiceError.rateLimited : ServiceError.httpStatus(http.statusCode)
        }
        return data
    }
}
