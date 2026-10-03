import Foundation
import WeatherWindowCore

/// The RainViewer list of available radar frames (`weather-maps.json`).
public struct RainViewerMaps: Decodable, Sendable {
    /// Address of the frame list, refreshed every 10 minutes by RainViewer.
    public static let endpoint = URL(string: "https://api.rainviewer.com/public/weather-maps.json")!

    /// Universal Blue, the only colour scheme RainViewer still serves.
    public static let colorScheme = 2

    public let host: String
    public let radar: Radar

    /// The radar part of the frame list.
    public struct Radar: Decodable, Sendable {
        public let past: [Frame]
    }

    /// One radar image, identified by its capture time and server path.
    public struct Frame: Decodable, Sendable, Hashable {
        public let time: Date
        public let path: String

        private enum CodingKeys: String, CodingKey {
            case time, path
        }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            time = Date(timeIntervalSince1970: try container.decode(TimeInterval.self, forKey: .time))
            path = try container.decode(String.self, forKey: .path)
        }
    }

    /// URL of a frame's tile without smoothing or snow colours.
    public func tileURL(for frame: Frame, tile: RadarTile = .melbourne) -> URL? {
        guard var components = URLComponents(string: host) else { return nil }
        components.path = frame.path
            + "/\(tile.size)/\(tile.zoom)/\(tile.x)/\(tile.y)/\(Self.colorScheme)/0_0.png"
        return components.url
    }
}
