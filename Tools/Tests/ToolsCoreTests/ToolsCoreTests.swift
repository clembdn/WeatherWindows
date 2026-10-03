import Foundation
import NowcastKit
import Testing
@testable import ToolsCore

@Test func parsesRoadmapPartsTestsAndCalendar() {
    let roadmap = Roadmap(markdown: """
        # Roadmap
        ## Part 1 — SolverKit · Linux · due 2026-10-06
        - [x] Types written
        - [ ] All tests green
        Tests: enumeratesAllOrders, paretoDropsDominated

        ## Calendar
        - [ ] 2026-10-07 · Mac 1 · Xcode project
        - [x] 2026-10-03 · Setup
        """)

    #expect(roadmap.parts.count == 1)
    #expect(roadmap.parts[0].title == "Part 1 — SolverKit")
    #expect(roadmap.parts[0].due == "2026-10-06")
    #expect(roadmap.parts[0].completedCount == 1)
    #expect(roadmap.parts[0].tests == ["enumeratesAllOrders", "paretoDropsDominated"])
    #expect(roadmap.events == [
        .init(date: "2026-10-07", name: "Mac 1", detail: "Xcode project", isDone: false),
        .init(date: "2026-10-03", name: "Setup", detail: "", isDone: true)
    ])
}

@Test func readsSwiftTestingResults() {
    let output = """
        ✔ Test laterOffsetDelaysRain() passed after 0.001 seconds.
        ✔ Test case passing 2 arguments dBZ → 20.0 to convertsReflectivityToRainRate(dBZ:expected:) passed
        ✔ Test convertsReflectivityToRainRate(dBZ:expected:) with 3 test cases passed after 0.001 seconds.
        ✘ Test paretoDropsDominated() recorded an issue at SolverTests.swift:12:5: Expectation failed
        ✘ Test paretoDropsDominated() failed after 0.002 seconds with 1 issue.
        """

    #expect(TestInventory.results(fromOutput: output) == [
        "laterOffsetDelaysRain": true,
        "convertsReflectivityToRainRate": true,
        "paretoDropsDominated": false
    ])
}

@Test func filesFramesUnderMelbourneLocalDay() {
    let store = RecordingStore(root: URL(filePath: "/tmp/rec"))
    // 2026-10-03 14:30 UTC is already 4 October in Melbourne.
    #expect(store.dayName(for: Date(timeIntervalSince1970: 1_791_037_800)) == "2026-10-04")
}

@Test func measuresRainNearTheCBD() {
    var values = [Float](repeating: ReflectivityPalette.noEchoDBZ, count: 512 * 512)
    for y in 270...279 {
        for x in 270...279 { values[y * 512 + x] = 30 }
    }
    var record = FrameRecord()

    record.measure(RainGrid(size: 512, values: values))

    #expect(record.maxDBZ == 30)
    #expect(record.rainFraction == 100.0 / Double(512 * 512))
    #expect(record.cbdRainFraction == 100.0 / 1681.0)
    #expect(record.hasStatistics)
}
