import Foundation
import NowcastKit
import SwiftData
import Testing
@testable import WeatherWindow

struct VerificationTests {
    @Test func bundlesTheWholeRainyDay() async throws {
        let frames = try await ReplayData().allRadarFrames()

        #expect(frames.count == 83)
        #expect(frames.first?.time == Date(timeIntervalSince1970: 1_790_984_400))
    }

    @Test func scoresEachLeadTimeAndKeepsTheScores() async throws {
        let container = try ModelContainer(for: VerificationScore.self,
                                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        // The seven images from 10:30 to 11:30: three forecasts can be checked 10 minutes ahead, one 30 minutes ahead.
        let all = try await ReplayData().allRadarFrames()
        let morning = all.filter {
            $0.time >= ReplayData.now.addingTimeInterval(-35 * 60) && $0.time <= ReplayData.now.addingTimeInterval(25 * 60)
        }

        let scores = try await VerificationViewModel().score(morning, source: "Test", context: container.mainContext)

        #expect(morning.count == 7)
        #expect(scores.map(\.leadMinutes) == [10, 20, 30])
        #expect(scores.map(\.cases) == [3, 2, 1])
        #expect(try container.mainContext.fetchCount(FetchDescriptor<VerificationScore>()) == 3)
    }
}
