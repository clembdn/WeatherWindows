import Foundation
import OSLog
import SwiftData

private let logger = Logger(subsystem: "edu.monash.cboudon.WeatherWindow", category: "data")

// What happened when adding an errand, so the form can say exactly what went wrong.
enum AddErrandResult {
    case added
    case duplicateName
    case failed(Error)
}

// Adds and deletes errands; the views read them with @Query.
@Observable
final class ErrandStore {
    @ObservationIgnored private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func add(_ errand: SavedErrand) -> AddErrandResult {
        let normalizedName = errand.normalizedName
        let sameName = FetchDescriptor<SavedErrand>(predicate: #Predicate { $0.normalizedName == normalizedName })
        do {
            if try context.fetchCount(sameName) > 0 {
                return .duplicateName
            }
            context.insert(errand)
            try context.save()
            return .added
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
}
