/// A square radar map tile in Web Mercator (slippy map) numbering.
public struct RadarTile: Hashable, Sendable, Codable {
    public var zoom: Int
    public var x: Int
    public var y: Int
    public var size: Int

    public init(zoom: Int, x: Int, y: Int, size: Int) {
        self.zoom = zoom
        self.x = x
        self.y = y
        self.size = size
    }

    /// The 512 px zoom 7 tile that contains Melbourne.
    public static let melbourne = RadarTile(zoom: 7, x: 115, y: 78, size: 512)
}
