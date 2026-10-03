import ForecastKit
import Foundation
import NowcastKit

/// Files shipped with the app (the staging package keeps them in its own bundle).
nonisolated enum AppResources {
    static var bundle: Bundle {
        #if SWIFT_PACKAGE
        Bundle.module
        #else
        Bundle.main
        #endif
    }
}

/// Live data, or the recorded rainy morning used for the demo.
nonisolated enum AppMode {
    static let replayKey = "replayMode"

    /// Replay is on when chosen in About, and always for UI tests.
    static func isReplay(setting: Bool) -> Bool {
        setting || LaunchOption.usesSampleData
    }

    static func now(isReplay: Bool) -> Date {
        isReplay ? ReplaySession.now : Date()
    }
}

/// Saturday 3 October 2026 in Melbourne: showers crossing the CBD, recorded by `ww record`.
nonisolated enum ReplaySession {
    /// The frozen clock: five minutes after the 11:00 radar image, as live data would lag.
    static let now = Date(timeIntervalSince1970: 1_790_989_500)

    static var label: String {
        "Replay · " + now.formatted(Date.FormatStyle(date: .abbreviated, time: .shortened, timeZone: AppClock.timeZone))
    }

    /// Radar tiles from 10:30 to 11:30; only those up to `now` are ever used for a forecast.
    static var frameFiles: [URL] {
        (AppResources.bundle.urls(forResourcesWithExtension: "png", subdirectory: nil) ?? [])
            .filter { $0.lastPathComponent.hasPrefix("replay-") }
    }

    /// The Open-Meteo forecast downloaded that morning.
    static func forecast() throws -> [WeatherSample] {
        guard let url = AppResources.bundle.url(forResource: "replay-forecast", withExtension: "json") else {
            throw ServiceError.other("The replay forecast is missing from the app.")
        }
        return try JSONDecoder().decode(OpenMeteoHourlyResponse.self, from: Data(contentsOf: url)).samples
    }

    static func frameSource() throws -> RecordedFrameSource {
        RecordedFrameSource(files: frameFiles, decoder: RadarTileDecoder(palette: try .universalBlue()))
    }
}
