import Foundation
import SolverKit
import SwiftData
import WeatherWindowCore

@Model
final class SavedErrand {
    var id = UUID()
    var name: String
    // Lowercase name without accents, used to find duplicates.
    var normalizedName: String
    var placeName: String
    var latitude: Double
    var longitude: Double
    var durationMinutes: Int
    var openingMinute: Int
    var closingMinute: Int

    @Relationship(deleteRule: .nullify, inverse: \PlannedStop.errand)
    var plannedStops: [PlannedStop] = []

    init(name: String, place: Place, durationMinutes: Int, openingMinute: Int, closingMinute: Int) {
        self.name = name
        normalizedName = Self.normalize(name)
        placeName = place.name
        latitude = place.location.latitude
        longitude = place.location.longitude
        self.durationMinutes = durationMinutes
        self.openingMinute = openingMinute
        self.closingMinute = closingMinute
    }

    var location: GeoPoint {
        GeoPoint(latitude: latitude, longitude: longitude)
    }

    // The solver's copy of this errand, with the same id.
    func makeStop() -> Stop {
        Stop(
            id: id,
            name: name,
            location: location,
            serviceDuration: TimeInterval(durationMinutes * 60),
            openingMinute: openingMinute,
            closingMinute: closingMinute
        )
    }

    nonisolated static func normalize(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_AU"))
    }
}

// A named location chosen in place search.
nonisolated struct Place: Hashable, Sendable, Codable {
    var name: String
    var location: GeoPoint
}
