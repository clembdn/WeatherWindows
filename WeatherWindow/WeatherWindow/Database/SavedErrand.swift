//
//  SavedErrand.swift
//  WeatherWindow
//
//  Created by Clement Boudon on 7/10/2026.
//

import Foundation
import SwiftData

@Model
final class SavedErrand {
    var id = UUID()
    var name: String
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

nonisolated struct Place: Hashable, Codable {
    var name: String
    var location: GeoPoint
}
