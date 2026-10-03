import Foundation

/// Imports the frames saved by the hourly "Radar backup" GitHub workflow into the local recordings.
public struct RadarSync: Sendable {
    public let store: RecordingStore
    public let repository: URL

    public init(store: RecordingStore, repository: URL) {
        self.store = store
        self.repository = repository
    }

    public struct Summary: Sendable {
        public var runs = 0
        public var imported = 0
        public var failedRuns: [Int] = []
    }

    public func sync() throws -> Summary {
        let list = Shell.run(
            ["gh", "run", "list", "--workflow", "radar-backup.yml", "--status", "success",
             "--limit", "1000", "--json", "databaseId"],
            in: repository
        )
        guard list.succeeded else { throw ToolError.commandFailed("gh run list (is gh installed and logged in?)") }

        struct Run: Decodable { let databaseId: Int }
        let runs = try JSONDecoder().decode([Run].self, from: Data(list.output.utf8)).map(\.databaseId)

        let syncedURL = store.root.appending(path: ".synced-runs")
        var synced = Set(((try? String(contentsOf: syncedURL, encoding: .utf8)) ?? "")
            .split(whereSeparator: \.isNewline).compactMap { Int($0) })

        var summary = Summary()
        for run in runs where !synced.contains(run) {
            let folder = FileManager.default.temporaryDirectory.appending(path: "ww-radar-\(run)")
            defer { try? FileManager.default.removeItem(at: folder) }

            let download = Shell.run(["gh", "run", "download", String(run), "--dir", folder.path], in: repository)
            guard download.succeeded else {
                summary.failedRuns.append(run)
                continue
            }
            summary.imported += try importFrames(from: folder)
            summary.runs += 1
            synced.insert(run)
        }

        try FileManager.default.createDirectory(at: store.root, withIntermediateDirectories: true)
        try synced.sorted().map(String.init).joined(separator: "\n")
            .write(to: syncedURL, atomically: true, encoding: .utf8)
        return summary
    }

    private func importFrames(from folder: URL) throws -> Int {
        guard let files = FileManager.default.enumerator(at: folder, includingPropertiesForKeys: nil) else { return 0 }
        var imported = 0
        for case let file as URL in files where file.pathExtension == "png" {
            guard let seconds = Int(file.deletingPathExtension().lastPathComponent) else { continue }
            let time = Date(timeIntervalSince1970: TimeInterval(seconds))
            guard !store.hasFrame(at: time) else { continue }

            let backupIndex = RecordingStore(root: file.deletingLastPathComponent().deletingLastPathComponent())
                .loadIndex(day: file.deletingLastPathComponent().lastPathComponent)
            let record = backupIndex[String(seconds)] ?? FrameRecord()
            try store.save(png: Data(contentsOf: file), at: time, record: record)
            imported += 1
        }
        return imported
    }
}
