import Foundation
import NowcastKit
import SolverKit
import Testing
import WeatherWindowCore
@testable import WeatherWindow

struct ReplaySessionTests {
    @Test func shipsTheRecordedMorning() async throws {
        #expect(ReplaySession.frameFiles.count == 7)
        #expect(try ReplaySession.forecast().count == 48)

        let frames = try await PlanServices.replay().radarFrames(ReplaySession.now)
        #expect(frames.count == 4)
        #expect(frames.allSatisfy { $0.time <= ReplaySession.now })
    }

    @Test func radarColoursFadeOutClearAir() {
        #expect(RadarColor.rgba(dBZ: ReflectivityPalette.noEchoDBZ).3 == 0)
        #expect(RadarColor.rgba(dBZ: 35).3 > 0)
        #expect(RadarColor.description(dBZ: 45) == "heavy rain")
    }
}

struct NextWalkTests {
    @Test func advisesFromTheRecordedRadar() async throws {
        let model = NextWalkViewModel(input: NextWalkInput(
            current: Place(name: "Melbourne Central", location: GeoPoint(latitude: -37.8102, longitude: 144.9628)),
            remaining: [Stop(name: "Library", location: GeoPoint(latitude: -37.8098, longitude: 144.9652),
                             serviceDuration: 20 * 60, openingMinute: 9 * 60, closingMinute: 18 * 60)],
            end: Place(name: "Flinders Street", location: GeoPoint(latitude: -37.8183, longitude: 144.9671))
        ))

        await model.load(services: .replay())

        guard case .loaded(let result) = model.state else {
            Issue.record("Expected advice, got \(model.state)")
            return
        }
        #expect(result.nowcast != nil)
        #expect(result.radarNotice == nil)
        #expect(result.recommended != nil)
        #expect(result.now == ReplaySession.now)
    }

    @Test func fallsBackToTheForecastWhenRadarIsStale() async throws {
        var services = PlanServices.replay()
        services.now = { ReplaySession.now.addingTimeInterval(45 * 60) }
        services.radarFrames = { _ in try await PlanServices.replay().radarFrames(ReplaySession.now) }
        let model = NextWalkViewModel(input: NextWalkInput(
            current: Place(name: "CBD", location: .melbourneCBD),
            remaining: [],
            end: Place(name: "Home", location: GeoPoint(latitude: -37.8183, longitude: 144.9671))
        ))

        await model.load(services: services)

        guard case .loaded(let result) = model.state else {
            Issue.record("Expected advice, got \(model.state)")
            return
        }
        #expect(result.nowcast == nil)
        #expect(result.radarNotice?.contains("too old") == true)
    }
}
