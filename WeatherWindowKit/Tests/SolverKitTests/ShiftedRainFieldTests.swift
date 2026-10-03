import Foundation
import Testing
import WeatherWindowCore
@testable import SolverKit

private struct RainAfter: RainField {
    let start: Date

    func weight(at point: GeoPoint, time: Date) -> Double {
        time >= start ? 1 : 0
    }
}

@Test func laterOffsetDelaysRain() {
    let start = Date(timeIntervalSince1970: 0)
    let field = ShiftedRainField(base: RainAfter(start: start), offset: 15 * 60)
    let anywhere = GeoPoint(latitude: 0, longitude: 0)

    #expect(field.weight(at: anywhere, time: start.addingTimeInterval(10 * 60)) == 0)
    #expect(field.weight(at: anywhere, time: start.addingTimeInterval(15 * 60)) == 1)
}

@Test func earlierOffsetBringsRainForward() {
    let start = Date(timeIntervalSince1970: 0)
    let field = ShiftedRainField(base: RainAfter(start: start), offset: -15 * 60)
    let anywhere = GeoPoint(latitude: 0, longitude: 0)

    #expect(field.weight(at: anywhere, time: start.addingTimeInterval(-15 * 60)) == 1)
    #expect(field.weight(at: anywhere, time: start.addingTimeInterval(-16 * 60)) == 0)
}

@Test func buildsFiveRobustnessScenarios() {
    let start = Date(timeIntervalSince1970: 0)
    let scenarios = ShiftedRainField.scenarios(around: RainAfter(start: start))
    let anywhere = GeoPoint(latitude: 0, longitude: 0)

    #expect(scenarios.count == 5)
    #expect(scenarios[0].weight(at: anywhere, time: start) == 1)
    #expect(scenarios.map { $0.weight(at: anywhere, time: start.addingTimeInterval(-20 * 60)) } == [0, 1, 0, 0, 0])
}
