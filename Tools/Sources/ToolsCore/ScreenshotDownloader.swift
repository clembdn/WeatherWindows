import Foundation

/// Fetches the newest app screenshots taken by the "Apple" workflow into `screenshots/`.
public struct ScreenshotDownloader: Sendable {
    public let repository: URL

    public init(repository: URL) {
        self.repository = repository
    }

    public struct Summary: Sendable {
        public let runID: Int
        public let title: String
        public let files: [String]
        public let folder: URL
    }

    public func download() throws -> Summary {
        let list = Shell.run(
            ["gh", "run", "list", "--workflow", "apple.yml", "--limit", "15", "--json", "databaseId,displayTitle,status"],
            in: repository
        )
        guard list.succeeded else { throw ToolError.commandFailed("gh run list (is gh installed and logged in?)") }

        struct Run: Decodable {
            let databaseId: Int
            let displayTitle: String
            let status: String
        }
        let runs = try JSONDecoder().decode([Run].self, from: Data(list.output.utf8)).filter { $0.status == "completed" }

        let folder = repository.appending(path: "screenshots")
        let staging = FileManager.default.temporaryDirectory.appending(path: "ww-screenshots")
        for run in runs {
            try? FileManager.default.removeItem(at: staging)
            let download = Shell.run(
                ["gh", "run", "download", String(run.databaseId), "--name", "screenshots", "--dir", staging.path],
                in: repository
            )
            let files = ((try? FileManager.default.contentsOfDirectory(atPath: staging.path)) ?? [])
                .filter { $0.hasSuffix(".png") }
                .sorted()
            guard download.succeeded, !files.isEmpty else { continue }

            try? FileManager.default.removeItem(at: folder)
            try FileManager.default.moveItem(at: staging, to: folder)
            return Summary(runID: run.databaseId, title: run.displayTitle, files: files, folder: folder)
        }
        throw ToolError.commandFailed("no screenshots found in the last \(runs.count) Apple runs")
    }
}
