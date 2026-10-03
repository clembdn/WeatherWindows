import Foundation

/// Which tests exist in the source tree and how the last `swift test` run went.
public enum TestInventory {
    /// Names of every function declared in the Swift files under a folder.
    public static func declaredFunctions(in folder: URL) -> Set<String> {
        guard let files = FileManager.default.enumerator(at: folder, includingPropertiesForKeys: nil) else { return [] }
        var names: Set<String> = []
        for case let file as URL in files where file.pathExtension == "swift" {
            guard let source = try? String(contentsOf: file, encoding: .utf8) else { continue }
            for match in source.matches(of: /func\s+([A-Za-z_][A-Za-z0-9_]*)\s*\(/) {
                names.insert(String(match.1))
            }
        }
        return names
    }

    /// Number of `@Test` functions under a folder.
    public static func testCount(in folder: URL) -> Int {
        guard let files = FileManager.default.enumerator(at: folder, includingPropertiesForKeys: nil) else { return 0 }
        var count = 0
        for case let file as URL in files where file.pathExtension == "swift" {
            let source = (try? String(contentsOf: file, encoding: .utf8)) ?? ""
            count += source.matches(of: /@Test\b/).count
        }
        return count
    }

    /// Pass (true) or fail (false) per test name, read from Swift Testing console output.
    public static func results(fromOutput output: String) -> [String: Bool] {
        var results: [String: Bool] = [:]
        for line in output.split(whereSeparator: \.isNewline) {
            guard let match = line.firstMatch(of: /^(✔|✘) Test (\w+)\(/) else { continue }
            let passed = match.1 == "✔"
            let name = String(match.2)
            results[name] = (results[name] ?? true) && passed
        }
        return results
    }
}

/// The outcome of the last `ww status --test`, kept between runs.
public struct TestRun: Codable, Sendable {
    public let date: Date
    public let succeeded: Bool
    public let results: [String: Bool]

    public init(date: Date, succeeded: Bool, results: [String: Bool]) {
        self.date = date
        self.succeeded = succeeded
        self.results = results
    }
}
