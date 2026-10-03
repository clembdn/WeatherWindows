import Foundation
#if canImport(Glibc)
import Glibc
#elseif canImport(Darwin)
import Darwin
#endif

/// ANSI styling, disabled when output is not a terminal or `NO_COLOR` is set.
public struct Terminal: Sendable {
    public let usesColor: Bool

    public init(usesColor: Bool? = nil) {
        self.usesColor = usesColor
            ?? (isatty(STDOUT_FILENO) == 1 && ProcessInfo.processInfo.environment["NO_COLOR"] == nil)
    }

    public enum Style: String, Sendable {
        case bold = "1", dim = "2", red = "31", green = "32", yellow = "33", blue = "34", cyan = "36"
    }

    public func style(_ text: String, _ styles: Style...) -> String {
        guard usesColor, !styles.isEmpty else { return text }
        return "\u{1B}[\(styles.map(\.rawValue).joined(separator: ";"))m\(text)\u{1B}[0m"
    }

    public static func bar(_ fraction: Double, width: Int = 12) -> String {
        let filled = Int((min(max(fraction, 0), 1) * Double(width)).rounded())
        return String(repeating: "█", count: filled) + String(repeating: "░", count: width - filled)
    }

    /// Pads to a visible width, ignoring ANSI escape codes.
    public static func pad(_ text: String, to width: Int) -> String {
        let visible = text.replacing(/\u{1B}\[[0-9;]*m/, with: "").count
        return text + String(repeating: " ", count: max(0, width - visible))
    }
}
