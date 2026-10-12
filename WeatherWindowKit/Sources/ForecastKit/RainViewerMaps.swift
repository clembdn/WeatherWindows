import Foundation
import WeatherWindowCore

/// The RainViewer list of available radar frames (`weather-maps.json`).
public struct RainViewerMaps: Decodable, Sendable {
    /// Address of the frame list, refreshed every 10 minutes by RainViewer.
    public static let endpoint = URL(string: "https://api.rainviewer.com/public/weather-maps.json")!

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
            let seconds = try container.decode(TimeInterval.self, forKey: .time)
            time = Date(timeIntervalSince1970: seconds)
            path = try container.decode(String.self, forKey: .path)
        }
    }

    /// URL of a frame's tile in Universal Blue (colour scheme 2, the only one left), without smoothing or snow.
    public func tileURL(for frame: Frame, tile: RadarTile = .melbourne) -> URL? {
        guard var components = URLComponents(string: host) else { return nil }
        components.path = frame.path + "/\(tile.size)/\(tile.zoom)/\(tile.x)/\(tile.y)/2/0_0.png"
        return components.url
    }
}
