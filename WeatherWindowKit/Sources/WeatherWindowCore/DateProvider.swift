import Foundation

/// Source of "now", injectable for tests and replay.
public protocol DateProvider: Sendable {
    var now: Date { get }
}

/// Reads the device clock.
public struct SystemDateProvider: DateProvider {
    public init() {}

    public var now: Date { Date() }
}

/// Always answers the same instant, used by tests and replay mode.
public struct FixedDateProvider: DateProvider {
    public let now: Date

    public init(now: Date) {
        self.now = now
    }
}
