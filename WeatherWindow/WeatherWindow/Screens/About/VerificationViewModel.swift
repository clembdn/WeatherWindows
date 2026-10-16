//
//  VerificationViewModel.swift
//  WeatherWindow
//
//  Created by Clement Boudon on 14/10/2026.
//

import Foundation
import SwiftData

enum VerificationSource: String {
    case recordedDay = "Rainy day, 3 Oct 2026"
    case lastTwoHours = "Last 2 hours, live"

    func frames() async throws -> [RadarFrame] {
        switch self {
        case .recordedDay:
            try await ReplayData().allRadarFrames()
        case .lastTwoHours:
            try await RainViewerService().frames(upTo: .now, count: 13)
        }
    }
}

@Observable
final class VerificationViewModel {
    static let leads = [10, 20, 30]

    private(set) var state = LoadState<[VerificationScore]>.idle
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

    @concurrent
    private static func evaluate(_ frames: [RadarFrame], leadMinutes: Int) async -> NowcastScorer.Evaluation {
        let region = PixelBox(minX: 278 - 96, minY: 277 - 96, maxX: 278 + 96, maxY: 277 + 96)
        return NowcastScorer.evaluate(frames: frames, leadMinutes: leadMinutes, region: region)
    }
}
