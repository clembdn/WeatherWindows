import Foundation

/// Runs other command-line programs (git, gh, swift) and captures their output.
public enum Shell {
    public struct Result: Sendable {
        public let status: Int32
        public let output: String

        public var succeeded: Bool { status == 0 }
    }

    public static func run(_ arguments: [String], in directory: URL? = nil, includeErrors: Bool = false) -> Result {
        let process = Process()
        process.executableURL = URL(filePath: "/usr/bin/env")
        process.arguments = arguments
        if let directory { process.currentDirectoryURL = directory }

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = includeErrors ? pipe : FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            return Result(status: -1, output: "")
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return Result(status: process.terminationStatus, output: String(decoding: data, as: UTF8.self))
    }
}
