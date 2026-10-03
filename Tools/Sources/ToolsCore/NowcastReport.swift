import Foundation
import NowcastKit

/// Replays the recorded radar days and scores the nowcast against persistence at several lead times.
public struct NowcastReport: Sendable {
    public let store: RecordingStore
    public let leads: [Int]
    /// Half-width of the scored area around the CBD, in pixels (96 px ≈ 46 km).
    public let radius: Int

    public init(store: RecordingStore, leads: [Int] = [10, 20, 30], radius: Int = 96) {
        self.store = store
        self.leads = leads
        self.radius = radius
    }

    public struct Row: Sendable {
        public let day: String
        public let lead: Int
        public let evaluation: Verifier.Evaluation
    }

    public func run(days requested: [String] = []) throws -> [Row] {
        let decoder = RadarTileDecoder(palette: try .universalBlue())
        let centre = FrameRecord.cbdPixel
        let region = PixelRegion(minX: centre.x - radius, minY: centre.y - radius,
                                 maxX: centre.x + radius, maxY: centre.y + radius)

        var rows: [Row] = []
        for day in requested.isEmpty ? store.days() : requested {
            let frames = try store.frameTimes(day: day).map { time in
                let png = try Data(contentsOf: store.frameURL(day: day, time: time))
                return RadarFrame(grid: try decoder.decode(png).grid, time: Date(timeIntervalSince1970: TimeInterval(time)))
            }
            for lead in leads {
                rows.append(Row(day: day, lead: lead,
                                evaluation: Verifier.evaluate(frames: frames, leadMinutes: lead, region: region)))
            }
        }
        return rows
    }

    public static func render(_ rows: [Row], terminal: Terminal = Terminal()) -> String {
        var lines = [terminal.style("Nowcast vs persistence · CSI at \(Int(ReflectivityConverter.rainThresholdDBZ)) dBZ within ~46 km of the CBD", .bold),
                     "  day          lead   cases   nowcast   persistence"]
        for row in rows {
            let nowcast = row.evaluation.nowcast.criticalSuccessIndex
            let persistence = row.evaluation.persistence.criticalSuccessIndex
            let format: (Double?) -> String = { $0.map { String(format: "%.3f", $0) } ?? "  –  " }
            let better = (nowcast ?? 0) > (persistence ?? 0)
            lines.append("  \(row.day)   \(String(format: "%2d", row.lead)) min   \(String(format: "%5d", row.evaluation.cases))   "
                + terminal.style(format(nowcast), better ? .green : .red) + "     " + format(persistence))
        }
        return lines.joined(separator: "\n")
    }
}
