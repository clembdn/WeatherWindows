import Foundation
import SolverKit
import SwiftData
import WeatherWindowCore

/// An errand in the user's library, reused from day to day.
@Model
final class SavedErrand {
    var name: String
    /// Lowercased, accent-free name used to detect duplicates.
    var normalizedName: String
    var placeName: String
    var latitude: Double
    var longitude: Double
    var durationMinutes: Int
    var openingMinute: Int
    var closingMinute: Int
    var createdAt: Date

    @Relationship(deleteRule: .nullify, inverse: \PlannedStop.errand)
    var plannedStops: [PlannedStop] = []

    init(draft: ErrandDraft, createdAt: Date = .now) {
        name = draft.name
        normalizedName = Self.normalize(draft.name)
        placeName = draft.place.name
        latitude = draft.place.location.latitude
        longitude = draft.place.location.longitude
        durationMinutes = draft.durationMinutes
        openingMinute = draft.openingMinute
        closingMinute = draft.closingMinute
        self.createdAt = createdAt
    }

    var location: GeoPoint {
        GeoPoint(latitude: latitude, longitude: longitude)
    }

    /// The solver's view of this errand.
    func makeStop(id: UUID = UUID()) -> Stop {
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

/// The values of a new errand, checked by the form before they reach the store.
nonisolated struct ErrandDraft: Hashable, Sendable {
    var name: String
    var place: Place
    var durationMinutes: Int
    var openingMinute: Int
    var closingMinute: Int
}

/// A named location chosen in place search.
nonisolated struct Place: Hashable, Sendable {
    var name: String
    var location: GeoPoint
}
