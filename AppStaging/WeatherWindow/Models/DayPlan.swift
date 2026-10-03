import Foundation
import SwiftData
import WeatherWindowCore

/// A saved day: where it starts and ends, the departure window, and the chosen schedule.
@Model
final class DayPlan {
    var date: Date
    var startName: String
    var startLatitude: Double
    var startLongitude: Double
    /// Nil when the day ends back at the start.
    var endName: String?
    var endLatitude: Double?
    var endLongitude: Double?
    var windowStart: Date
    var windowEnd: Date
    var departure: Date?
    var returnTime: Date?
    var robustExposure: Double?

    @Relationship(deleteRule: .cascade, inverse: \PlannedStop.plan)
    var stops: [PlannedStop] = []

    init(date: Date, start: Place, end: Place?, window: ClosedRange<Date>) {
        self.date = date
        startName = start.name
        startLatitude = start.location.latitude
        startLongitude = start.location.longitude
        endName = end?.name
        endLatitude = end?.location.latitude
        endLongitude = end?.location.longitude
        windowStart = window.lowerBound
        windowEnd = window.upperBound
    }

    var start: GeoPoint {
        GeoPoint(latitude: startLatitude, longitude: startLongitude)
    }

    var end: GeoPoint {
        guard let endLatitude, let endLongitude else { return start }
        return GeoPoint(latitude: endLatitude, longitude: endLongitude)
    }

    var orderedStops: [PlannedStop] {
        stops.sorted { $0.rank < $1.rank }
    }
}
