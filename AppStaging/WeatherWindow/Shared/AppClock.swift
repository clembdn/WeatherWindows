import Foundation

/// Melbourne clock for opening hours and display; every stored instant stays a `Date`.
nonisolated enum AppClock {
    static let timeZone = TimeZone(identifier: "Australia/Melbourne") ?? .current

    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }

    /// Minutes since midnight, Melbourne time.
    static func minute(of date: Date) -> Int {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
    }

    /// The instant at a clock time on the same Melbourne day as `day`.
    static func date(minute: Int, on day: Date = .now) -> Date {
        calendar.date(bySettingHour: minute / 60 % 24, minute: minute % 60, second: 0, of: day) ?? day
    }

    /// "09:30" from minutes since midnight.
    static func string(minute: Int) -> String {
        String(format: "%02d:%02d", minute / 60 % 24, minute % 60)
    }

    /// Short Melbourne time of an instant, in the user's locale.
    static func time(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(date: .omitted, time: .shortened, timeZone: timeZone))
    }
}
