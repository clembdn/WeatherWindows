import Foundation

/// The project plan read from `ROADMAP.md`: parts with checklists and spec tests, plus dated events.
public struct Roadmap: Sendable {
    public struct Item: Sendable, Equatable {
        public let isDone: Bool
        public let text: String
    }

    public struct Part: Sendable {
        public let title: String
        public let place: String
        public let due: String
        public var items: [Item] = []
        public var tests: [String] = []

        public var completedCount: Int { items.count { $0.isDone } }
        public var isComplete: Bool { !items.isEmpty && completedCount == items.count }
    }

    public struct Event: Sendable, Equatable {
        public let date: String
        public let name: String
        public let detail: String
        public let isDone: Bool
    }

    public private(set) var parts: [Part] = []
    public private(set) var events: [Event] = []

    /// Part headings look like `## Part 1 — SolverKit · Linux · due 2026-10-06`; events like
    /// `- [ ] 2026-10-07 · Mac 1 · goal` under `## Calendar`.
    public init(markdown: String) {
        var inCalendar = false
        for rawLine in markdown.split(whereSeparator: \.isNewline) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)

            if line.hasPrefix("## ") {
                let heading = line.dropFirst(3)
                inCalendar = heading == "Calendar"
                let fields = heading.components(separatedBy: " · ")
                if !inCalendar, fields.count == 3, fields[2].hasPrefix("due ") {
                    parts.append(Part(title: fields[0], place: fields[1], due: String(fields[2].dropFirst(4))))
                }
                continue
            }

            if let item = Self.checkbox(line) {
                if inCalendar {
                    let fields = item.text.components(separatedBy: " · ")
                    guard fields.count >= 2 else { continue }
                    events.append(Event(
                        date: fields[0], name: fields[1],
                        detail: fields.dropFirst(2).joined(separator: " · "), isDone: item.isDone
                    ))
                } else if !parts.isEmpty {
                    parts[parts.count - 1].items.append(item)
                }
            } else if line.hasPrefix("Tests:"), !parts.isEmpty {
                parts[parts.count - 1].tests = line.dropFirst(6)
                    .split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
            }
        }
    }

    private static func checkbox(_ line: String) -> Item? {
        if line.hasPrefix("- [ ] ") { return Item(isDone: false, text: String(line.dropFirst(6))) }
        if line.lowercased().hasPrefix("- [x] ") { return Item(isDone: true, text: String(line.dropFirst(6))) }
        return nil
    }
}
