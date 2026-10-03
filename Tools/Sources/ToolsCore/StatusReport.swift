import Foundation

/// The `ww status` dashboard: roadmap, tests, CI, radar recordings and git, in one screen.
public struct StatusReport {
    public let repository: URL
    public let terminal: Terminal
    public let now: Date
    public let runTests: Bool

    public init(repository: URL, terminal: Terminal = Terminal(), now: Date = Date(), runTests: Bool = false) {
        self.repository = repository
        self.terminal = terminal
        self.now = now
        self.runTests = runTests
    }

    private var kitFolder: URL { repository.appending(path: "WeatherWindowKit") }
    private var testFolders: [URL] { [kitFolder.appending(path: "Tests"), repository.appending(path: "WeatherWindow"), repository.appending(path: "AppStaging")] }
    private var lastRunURL: URL { kitFolder.appending(path: ".build/ww-last-test-run.json") }
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = RecordingStore.timeZone
        return calendar
    }

    public func render() -> String {
        let roadmap = Roadmap(markdown: (try? String(contentsOf: repository.appending(path: "ROADMAP.md"), encoding: .utf8)) ?? "")
        let declared = testFolders.reduce(into: Set<String>()) { $0.formUnion(TestInventory.declaredFunctions(in: $1)) }
        let testRun = runTests ? runKitTests() : loadLastRun()

        var lines: [String] = []
        lines += header(roadmap: roadmap, declared: declared)
        lines += upcoming(roadmap)
        lines += roadmapSection(roadmap, declared: declared, testRun: testRun)
        lines += testsSection(testRun)
        lines += ciSection()
        lines += radarSection()
        lines += gitSection()
        return lines.joined(separator: "\n")
    }

    // MARK: Sections

    private func header(roadmap: Roadmap, declared: Set<String>) -> [String] {
        let items = roadmap.parts.flatMap(\.items)
        let done = items.count { $0.isDone }
        let specTests = roadmap.parts.flatMap(\.tests)
        let written = specTests.count { declared.contains($0) }
        let fraction = items.isEmpty ? 0 : Double(done) / Double(items.count)

        return [
            terminal.style("WeatherWindow", .bold, .cyan) + "  "
                + terminal.style(format(now, "EEEE d MMMM yyyy, HH:mm") + " Melbourne", .dim),
            "Overall  \(Terminal.bar(fraction, width: 24)) \(Int((fraction * 100).rounded())) %"
                + "  ·  \(done)/\(items.count) checks  ·  \(written)/\(specTests.count) spec tests written",
            ""
        ]
    }

    private func upcoming(_ roadmap: Roadmap) -> [String] {
        let next = roadmap.events.filter { !$0.isDone && (daysUntil($0.date) ?? -1) >= 0 }.prefix(4)
        guard !next.isEmpty else { return [] }
        var lines = [title("NEXT")]
        for event in next {
            let days = daysUntil(event.date) ?? 0
            let when = days == 0 ? terminal.style("today", .bold, .yellow) : "in \(days) day\(days == 1 ? "" : "s")"
            lines.append("  " + Terminal.pad(shortDate(event.date), to: 12) + Terminal.pad(when, to: 13)
                + terminal.style(event.name, .bold) + (event.detail.isEmpty ? "" : " — " + event.detail))
        }
        return lines + [""]
    }

    private func roadmapSection(_ roadmap: Roadmap, declared: Set<String>, testRun: TestRun?) -> [String] {
        var lines = [title("ROADMAP")]
        let titleWidth = (roadmap.parts.map(\.title.count).max() ?? 0) + 2

        for part in roadmap.parts {
            let late = (daysUntil(part.due) ?? 0) < 0 && !part.isComplete
            let icon = part.isComplete ? terminal.style("✔", .green)
                : late ? terminal.style("!", .red, .bold)
                : part.completedCount > 0 ? terminal.style("◐", .yellow) : terminal.style("○", .dim)
            let fraction = part.items.isEmpty ? 0 : Double(part.completedCount) / Double(part.items.count)

            var testsText = ""
            if !part.tests.isEmpty {
                let written = part.tests.count { declared.contains($0) }
                testsText = "tests \(written)/\(part.tests.count) written"
                if let results = testRun?.results, part.tests.contains(where: { results[$0] != nil }) {
                    let failing = part.tests.filter { results[$0] == false }
                    let passing = part.tests.count { results[$0] == true }
                    testsText += failing.isEmpty
                        ? terminal.style(" · \(passing) pass", .green)
                        : terminal.style(" · \(failing.count) FAIL", .red, .bold)
                } else if written > 0 {
                    testsText += terminal.style(" · run on iOS (CI)", .dim)
                }
            }

            let due = late ? terminal.style("due \(shortDate(part.due)) · late", .red)
                : "due \(shortDate(part.due))"
            lines.append("  \(icon) " + Terminal.pad(terminal.style(part.title, .bold), to: titleWidth)
                + Terminal.pad(part.place, to: 9)
                + "\(Terminal.bar(fraction)) " + Terminal.pad("\(part.completedCount)/\(part.items.count)", to: 6)
                + Terminal.pad(testsText, to: 36) + terminal.style(due, .dim))
        }

        if let current = roadmap.parts.first(where: { !$0.isComplete }) {
            lines.append("")
            lines.append("  " + terminal.style("Next up in \(current.title):", .bold))
            for item in current.items where !item.isDone {
                lines.append("    ☐ " + item.text)
            }
            let missing = current.tests.filter { !declared.contains($0) }
            if !missing.isEmpty {
                lines.append("    ☐ write tests: " + missing.joined(separator: ", "))
            }
        }
        return lines + [""]
    }

    private func testsSection(_ testRun: TestRun?) -> [String] {
        let count = testFolders.reduce(0) { $0 + TestInventory.testCount(in: $1) }
        var line = "  \(count) @Test functions in the package and app"
        if let testRun {
            let failing = testRun.results.filter { !$0.value }.keys.sorted()
            line += " · last run " + relative(testRun.date) + ": "
            if testRun.succeeded && failing.isEmpty {
                line += terminal.style("✔ \(testRun.results.count) passed", .green)
            } else {
                line += terminal.style("✘ failing: " + (failing.isEmpty ? "build error" : failing.joined(separator: ", ")), .red, .bold)
            }
        } else {
            line += terminal.style(" · not run yet (./ww status --test)", .dim)
        }
        return [title("TESTS"), line, ""]
    }

    private func ciSection() -> [String] {
        let result = Shell.run(
            ["gh", "run", "list", "--limit", "30", "--json", "workflowName,status,conclusion,createdAt,displayTitle"],
            in: repository
        )
        struct Run: Decodable {
            let workflowName: String
            let status: String
            let conclusion: String
            let createdAt: Date
            let displayTitle: String
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard result.succeeded, let runs = try? decoder.decode([Run].self, from: Data(result.output.utf8)) else {
            return [title("CI"), terminal.style("  unavailable (gh not logged in, or nothing pushed yet)", .dim), ""]
        }

        var lines = [title("CI  (GitHub Actions)")]
        var seen: Set<String> = []
        for run in runs where seen.insert(run.workflowName).inserted {
            let state: String = switch (run.status, run.conclusion) {
            case ("completed", "success"): terminal.style("✔ success", .green)
            case ("completed", let conclusion): terminal.style("✘ \(conclusion)", .red, .bold)
            default: terminal.style("● \(run.status.replacing("_", with: " "))", .yellow)
            }
            lines.append("  " + Terminal.pad(run.workflowName, to: 15) + Terminal.pad(state, to: 15)
                + Terminal.pad(relative(run.createdAt), to: 13) + terminal.style(String(run.displayTitle.prefix(50)), .dim))
        }
        if runs.isEmpty { lines.append(terminal.style("  no runs yet", .dim)) }
        return lines + [""]
    }

    private func radarSection() -> [String] {
        let store = RecordingStore(root: repository.appending(path: "recordings"))
        let days = store.days()
        guard !days.isEmpty else {
            return [title("RADAR"), terminal.style("  no recordings yet (./ww record)", .red), ""]
        }

        let indexes = days.map { (day: $0, index: store.loadIndex(day: $0), times: store.frameTimes(day: $0)) }
        let allTimes = indexes.flatMap(\.times)
        let rainyDays = indexes.filter { day in
            day.index.values.count { ($0.cbdRainFraction ?? 0) >= 0.05 } >= 6
        }

        var lines = [title("RADAR  (recordings/)")]
        if let last = allTimes.max() {
            let age = now.timeIntervalSince1970 - Double(last)
            let freshness = age < 3600 ? terminal.style("✔", .green)
                : terminal.style("⚠ is the cron running?", .yellow, .bold)
            lines.append("  Last frame \(relative(Date(timeIntervalSince1970: Double(last)))) \(freshness)"
                + "  ·  \(days.count) day\(days.count == 1 ? "" : "s")  ·  \(allTimes.count) frames  ·  "
                + terminal.style("\(rainyDays.count) rainy day\(rainyDays.count == 1 ? "" : "s") near the CBD",
                                 rainyDays.isEmpty ? .yellow : .green))
        }
        lines.append("  " + String(repeating: " ", count: 12) + terminal.style("0h    6h    12h   18h", .dim)
                     + terminal.style("     rain within 10 km of the CBD", .dim))

        for day in indexes.suffix(7) {
            var hourly = [Double?](repeating: nil, count: 24)
            for time in day.times {
                let hour = calendar.component(.hour, from: Date(timeIntervalSince1970: Double(time)))
                let value = day.index[String(time)]?.cbdRainFraction ?? 0
                hourly[hour] = max(hourly[hour] ?? 0, value)
            }
            let spark = hourly.map { value -> String in
                guard let value else { return terminal.style("·", .dim) }
                let levels = Array("▁▂▃▄▅▆▇█")
                let level = value == 0 ? 0 : 1 + Int((min(value * 2, 1) * 6).rounded())
                return terminal.style(String(levels[level]), value > 0 ? .blue : .dim)
            }.joined()
            let peak = day.index.values.compactMap(\.maxDBZ).max().map { "peak \(Int($0)) dBZ" } ?? ""
            lines.append("  " + Terminal.pad(shortDate(day.day), to: 12) + spark
                + "  \(day.times.count) frames  " + terminal.style(peak, .dim))
        }
        return lines + [""]
    }

    private func gitSection() -> [String] {
        let branch = Shell.run(["git", "rev-parse", "--abbrev-ref", "HEAD"], in: repository).output
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let last = Shell.run(["git", "log", "-1", "--format=%ct|%s"], in: repository).output
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let dirty = Shell.run(["git", "status", "--porcelain"], in: repository).output
            .split(whereSeparator: \.isNewline).count
        let unpushed = Shell.run(["git", "rev-list", "--count", "@{u}..HEAD"], in: repository)

        var parts = [terminal.style(branch.isEmpty ? "?" : branch, .bold)]
        let fields = last.split(separator: "|", maxSplits: 1)
        if fields.count == 2, let seconds = Double(fields[0]) {
            parts.append("last commit \(relative(Date(timeIntervalSince1970: seconds))) “\(fields[1].prefix(50))”")
        } else {
            parts.append("no commits yet")
        }
        parts.append(dirty == 0 ? terminal.style("clean", .green) : terminal.style("\(dirty) uncommitted", .yellow))
        if unpushed.succeeded, let count = Int(unpushed.output.trimmingCharacters(in: .whitespacesAndNewlines)) {
            parts.append(count == 0 ? terminal.style("pushed", .green) : terminal.style("\(count) unpushed", .yellow))
        } else {
            parts.append(terminal.style("no upstream", .yellow))
        }
        return [title("GIT"), "  " + parts.joined(separator: "  ·  ")]
    }

    // MARK: Tests

    private func runKitTests() -> TestRun {
        let result = Shell.run(["swift", "test"], in: kitFolder, includeErrors: true)
        let run = TestRun(date: now, succeeded: result.succeeded, results: TestInventory.results(fromOutput: result.output))
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        try? encoder.encode(run).write(to: lastRunURL, options: .atomic)
        return run
    }

    private func loadLastRun() -> TestRun? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return (try? Data(contentsOf: lastRunURL)).flatMap { try? decoder.decode(TestRun.self, from: $0) }
    }

    // MARK: Formatting

    private func title(_ text: String) -> String {
        terminal.style(text, .bold)
    }

    private func date(fromDay day: String) -> Date? {
        let parts = day.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }

    private func daysUntil(_ day: String) -> Int? {
        guard let target = date(fromDay: day) else { return nil }
        return calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: target).day
    }

    private func shortDate(_ day: String) -> String {
        date(fromDay: day).map { format($0, "EEE d MMM") } ?? day
    }

    private func format(_ date: Date, _ pattern: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_AU")
        formatter.timeZone = RecordingStore.timeZone
        formatter.dateFormat = pattern
        return formatter.string(from: date)
    }

    private func relative(_ date: Date) -> String {
        let seconds = Int(now.timeIntervalSince(date))
        switch seconds {
        case ..<60: return "just now"
        case ..<3600: return "\(seconds / 60) min ago"
        case ..<86_400: return "\(seconds / 3600) h ago"
        default: return "\(seconds / 86_400) d ago"
        }
    }
}
