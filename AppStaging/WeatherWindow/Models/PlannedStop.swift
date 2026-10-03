import Foundation
import SwiftData
import WeatherWindowCore

/// One errand of a saved day. Values are copied, so editing or deleting the errand never rewrites history.
@Model
final class PlannedStop {
    var name: String
    var latitude: Double
    var longitude: Double
    var durationMinutes: Int
    var openingMinute: Int
    var closingMinute: Int
    var rank: Int
    var arrival: Date?
    var departure: Date?

    var plan: DayPlan?
    var errand: SavedErrand?

    init(copying errand: SavedErrand, rank: Int) {
        name = errand.name
        latitude = errand.latitude
        longitude = errand.longitude
        durationMinutes = errand.durationMinutes
        openingMinute = errand.openingMinute
        closingMinute = errand.closingMinute
        self.rank = rank
        self.errand = errand
    }

    var location: GeoPoint {
        GeoPoint(latitude: latitude, longitude: longitude)
    }
}
