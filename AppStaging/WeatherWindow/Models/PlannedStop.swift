import Foundation
import SolverKit
import SwiftData
import WeatherWindowCore

// One errand of a saved day. The values are copied, so editing or deleting the errand never rewrites history.
@Model
final class PlannedStop {
    var name: String
    var latitude: Double
    var longitude: Double
    var durationMinutes: Int
    var openingMinute: Int
    var closingMinute: Int
    var rank: Int
    var arrival: Date
    var departure: Date

    var plan: DayPlan?
    var errand: SavedErrand?

    init(errand: SavedErrand, rank: Int, arrival: Date, departure: Date) {
        name = errand.name
        latitude = errand.latitude
        longitude = errand.longitude
        durationMinutes = errand.durationMinutes
        openingMinute = errand.openingMinute
        closingMinute = errand.closingMinute
        self.rank = rank
        self.arrival = arrival
        self.departure = departure
        self.errand = errand
    }

    var location: GeoPoint {
        GeoPoint(latitude: latitude, longitude: longitude)
    }

    // The solver's copy of this stop, to re-plan the rest of the day.
    func makeStop() -> Stop {
        Stop(
            name: name,
            location: location,
            serviceDuration: TimeInterval(durationMinutes * 60),
            openingMinute: openingMinute,
            closingMinute: closingMinute
        )
    }
}
