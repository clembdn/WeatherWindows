import Foundation
import OSLog

extension Logger {
    nonisolated private static let subsystem = Bundle.main.bundleIdentifier ?? "WeatherWindow"

    nonisolated static let network = Logger(subsystem: subsystem, category: "network")
    nonisolated static let data = Logger(subsystem: subsystem, category: "data")
    nonisolated static let location = Logger(subsystem: subsystem, category: "location")
}
