import Foundation
import SwiftData
import WeatherWindowCore

// A saved day: where it starts and ends, and the schedule that was chosen.
@Model
final class DayPlan {
    var departure: Date
    var returnTime: Date
    var robustExposure: Double
    var startName: String
    var startLatitude: Double
    var startLongitude: Double
    // Nil when the day ends back at the start.
    var endName: String?
    var endLatitude: Double?
    var endLongitude: Double?

    @Relationship(deleteRule: .cascade, inverse: \PlannedStop.plan)
    var stops: [PlannedStop] = []

    init(departure: Date, returnTime: Date, robustExposure: Double, start: Place, end: Place?) {
        self.departure = departure
        self.returnTime = returnTime
        self.robustExposure = robustExposure
        startName = start.name
        startLatitude = start.location.latitude
        startLongitude = start.location.longitude
        endName = end?.name
        endLatitude = end?.location.latitude
        endLongitude = end?.location.longitude
    }

    var start: Place {
        Place(name: startName, location: GeoPoint(latitude: startLatitude, longitude: startLongitude))
    }

    var end: Place {
        guard let endName, let endLatitude, let endLongitude else { return start }
        return Place(name: endName, location: GeoPoint(latitude: endLatitude, longitude: endLongitude))
    }

    var orderedStops: [PlannedStop] {
        stops.sorted { $0.rank < $1.rank }
    }
}
