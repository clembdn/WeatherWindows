import Foundation
import NowcastKit
import SwiftData

// Which radar images are replayed to score the nowcast.
enum VerificationSource: String {
    case recordedDay = "Rainy day, 3 Oct 2026"
    case lastTwoHours = "Last 2 hours, live"

    func frames() async throws -> [RadarFrame] {
        switch self {
        case .recordedDay:
            try await ReplayData().allRadarFrames()
        case .lastTwoHours:
            // RainViewer keeps 2 hours of images, one every 10 minutes.
            try await LiveRainViewerSource().frames(upTo: .now, count: 13)
        }
    }
}

// Replays radar images: from each image, forecast 10, 20 and 30 minutes ahead, then compare with what the radar saw.
@Observable
final class VerificationViewModel {
    static let leads = [10, 20, 30]

    private(set) var state = LoadState<[VerificationScore]>.idle
    // A whole day takes about half a minute in a debug build, so each lead time is announced.
    private(set) var progress: String?

    func score(_ source: VerificationSource, context: ModelContext) async {
        state = .loading
        do {
            let frames = try await source.frames()
            state = .loaded(try await score(frames, source: source.rawValue, context: context))
        } catch {
            let serviceError = ServiceError(error)
            state = serviceError == .cancelled ? .idle : .failed(serviceError)
        }
    }

    // Scores the frames and keeps one VerificationScore per lead time in SwiftData.
    func score(_ frames: [RadarFrame], source: String, context: ModelContext) async throws -> [VerificationScore] {
        let date = Date.now
        var scores: [VerificationScore] = []
        for lead in Self.leads {
            progress = "Scoring the forecasts \(lead) minutes ahead…"
            let evaluation = await Self.evaluate(frames, leadMinutes: lead)
            let score = VerificationScore(
                date: date,
                source: source,
                leadMinutes: lead,
                cases: evaluation.cases,
                nowcastCSI: evaluation.nowcast.criticalSuccessIndex,
                persistenceCSI: evaluation.persistence.criticalSuccessIndex
            )
            context.insert(score)
            scores.append(score)
        }
        progress = nil
        try context.save()
        return scores
    }

    // Motion is measured from every image: heavy work, so off the main thread.
    @concurrent
    private static func evaluate(_ frames: [RadarFrame], leadMinutes: Int) async -> Verifier.Evaluation {
        // The same area as `ww verify`: 96 pixels (about 46 km) around the CBD pixel (278, 277).
        let region = PixelRegion(minX: 278 - 96, minY: 277 - 96, maxX: 278 + 96, maxY: 277 + 96)
        return Verifier.evaluate(frames: frames, leadMinutes: leadMinutes, region: region)
    }
}
