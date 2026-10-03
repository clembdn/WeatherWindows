import Foundation
import NowcastKit
import ToolsCore

let usage = """
    Usage: ww <command>

      status [--test]   Progress dashboard: roadmap, tests, CI, radar, git (--test runs swift test first)
      record [--out D]  Download new RainViewer frames into recordings/ (run by cron every 30 min)
      sync-radar        Import the frames saved by the hourly GitHub backup workflow
      screenshots       Download the latest app screenshots taken by CI into screenshots/
      verify [day…]     Replay recorded radar: nowcast vs persistence (CSI) at 10, 20 and 30 min
    """

func repositoryRoot() throws -> URL {
    var folder = URL(filePath: FileManager.default.currentDirectoryPath)
    while folder.path != "/" {
        if FileManager.default.fileExists(atPath: folder.appending(path: "WeatherWindowKit/Package.swift").path) {
            return folder
        }
        folder.deleteLastPathComponent()
    }
    throw ToolError.repositoryNotFound
}

func value(after flag: String, in arguments: [String]) -> String? {
    guard let index = arguments.firstIndex(of: flag), index + 1 < arguments.count else { return nil }
    return arguments[index + 1]
}

func printError(_ message: String) {
    FileHandle.standardError.write(Data((message + "\n").utf8))
}

let arguments = Array(CommandLine.arguments.dropFirst())

do {
    let root = try repositoryRoot()
    switch arguments.first {
    case "status":
        print(StatusReport(repository: root, runTests: arguments.contains("--test")).render())

    case "record":
        let out = value(after: "--out", in: arguments).map { URL(filePath: $0) } ?? root.appending(path: "recordings")
        let recorder = RadarRecorder(
            store: RecordingStore(root: out),
            decoder: RadarTileDecoder(palette: try .universalBlue())
        )
        let summary = try await recorder.record()
        let stamp = Date().formatted(.iso8601)
        print("\(stamp) \(summary.saved) new, \(summary.skipped) already on disk, \(summary.measured) measured, \(summary.failures.count) failed")
        summary.failures.forEach(printError)
        exit(summary.failures.isEmpty ? 0 : 1)

    case "sync-radar":
        let store = RecordingStore(root: root.appending(path: "recordings"))
        let summary = try RadarSync(store: store, repository: root).sync()
        let measured = try RadarRecorder(store: store, decoder: RadarTileDecoder(palette: try .universalBlue()))
            .measureMissingStatistics()
        print("\(summary.runs) backup run(s) synced, \(summary.imported) frame(s) imported, \(measured) measured")
        if !summary.failedRuns.isEmpty {
            printError("Could not download runs (probably expired): \(summary.failedRuns.map(String.init).joined(separator: ", "))")
        }

    case "screenshots":
        let summary = try ScreenshotDownloader(repository: root).download()
        print("Screenshots from run \(summary.runID) “\(summary.title)”:")
        summary.files.forEach { print("  \(summary.folder.path)/\($0)") }

    case "verify":
        let store = RecordingStore(root: root.appending(path: "recordings"))
        let rows = try NowcastReport(store: store).run(days: Array(arguments.dropFirst()))
        print(NowcastReport.render(rows))

    default:
        print(usage)
    }
} catch {
    printError("ww: \(error)")
    exit(2)
}
