import Foundation
import WeatherWindowCore

/// Everything the solver needs, as plain values so it can cross actors safely.
public struct PlanRequest: Sendable {
    public var start: GeoPoint
    public var end: GeoPoint
    public var stops: [Stop]
    public var departureWindow: ClosedRange<Date>
    public var departureStep: TimeInterval
    public var walkingTimes: [Node: [Node: TimeInterval]]
    public var timeZone: TimeZone

    public init(
        start: GeoPoint,
        end: GeoPoint,
        stops: [Stop],
        departureWindow: ClosedRange<Date>,
        departureStep: TimeInterval = 5 * 60,
        walkingTimes: [Node: [Node: TimeInterval]],
        timeZone: TimeZone
    ) {
        self.start = start
        self.end = end
        self.stops = stops
        self.departureWindow = departureWindow
        self.departureStep = departureStep
        self.walkingTimes = walkingTimes
        self.timeZone = timeZone
    }

    /// Every departure time tried: the window start, then every step until the window end.
    public var departureTimes: [Date] {
        guard departureStep > 0 else { return [] }
        var times: [Date] = []
        var time = departureWindow.lowerBound
        while time <= departureWindow.upperBound {
            times.append(time)
            time.addTimeInterval(departureStep)
        }
        return times
    }

    func location(of node: Node) -> GeoPoint? {
        switch node {
        case .start: start
        case .end: end
        case .stop(let id): stops.first { $0.id == id }?.location
        }
    }
}
