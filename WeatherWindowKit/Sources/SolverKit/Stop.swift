import Foundation
import WeatherWindowCore

/// A place in the walking-time matrix: the start, the end, or one of the errands.
public enum Node: Hashable, Sendable {
    case start
    case end
    case stop(UUID)
}

/// An errand of the day, with how long it takes and when the place is open.
public struct Stop: Identifiable, Hashable, Sendable {
    public let id: UUID
    public var name: String
    public var location: GeoPoint
    public var serviceDuration: TimeInterval
    /// Minutes since midnight, in the request's time zone.
    public var openingMinute: Int
    public var closingMinute: Int

    public init(
        id: UUID = UUID(),
        name: String,
        location: GeoPoint,
        serviceDuration: TimeInterval,
        openingMinute: Int,
        closingMinute: Int
    ) {
        self.id = id
        self.name = name
        self.location = location
        self.serviceDuration = serviceDuration
        self.openingMinute = openingMinute
        self.closingMinute = closingMinute
    }
}
