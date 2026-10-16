//
//  ErrandStore.swift
//  WeatherWindow
//
//  Created by Clement Boudon on 7/10/2026.
//

import Foundation
import OSLog
import SwiftData

private let logger = Logger(subsystem: "edu.monash.cboudon.WeatherWindow", category: "data")

enum SaveErrandResult {
    case saved
    case duplicateName
    case failed(Error)
}

@Observable
final class ErrandStore {
    @ObservationIgnored private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func add(_ errand: SavedErrand) -> SaveErrandResult {
        do {
            if try hasOtherErrand(named: errand.normalizedName, than: nil) {
                return .duplicateName
            }
            context.insert(errand)
            try context.save()
            return .saved
        } catch {
            return .failed(error)
        }
    }

    func update(_ errand: SavedErrand, with edited: SavedErrand) -> SaveErrandResult {
        do {
            if try hasOtherErrand(named: edited.normalizedName, than: errand.id) {
                return .duplicateName
            }
            errand.name = edited.name
            errand.normalizedName = edited.normalizedName
            errand.placeName = edited.placeName
            errand.latitude = edited.latitude
            errand.longitude = edited.longitude
            errand.durationMinutes = edited.durationMinutes
            errand.openingMinute = edited.openingMinute
            errand.closingMinute = edited.closingMinute
            try context.save()
            return .saved
        } catch {
            return .failed(error)
        }
    }

    func delete(_ errands: [SavedErrand]) {
        for errand in errands {
            context.delete(errand)
        }
        do {
            try context.save()
        } catch {
            logger.error("Errands could not be deleted: \(error.localizedDescription)")
        }
    }

    private func hasOtherErrand(named normalizedName: String, than id: UUID?) throws -> Bool {
        let sameName = FetchDescriptor<SavedErrand>(predicate: #Predicate { $0.normalizedName == normalizedName })
        let errands = try context.fetch(sameName)
        return errands.contains { $0.id != id }
    }
}
