import Foundation
import OSLog
import SwiftData

/// What happened when adding an errand, so the form can say exactly what went wrong.
enum AddErrandResult {
    case added
    case duplicateName
    case failed(any Error)
}

/// Owns writes to the errand library; views read it with `@Query`.
@Observable
final class ErrandStore {
    @ObservationIgnored private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func add(_ draft: ErrandDraft) -> AddErrandResult {
        let normalizedName = SavedErrand.normalize(draft.name)
        do {
            let sameName = FetchDescriptor<SavedErrand>(predicate: #Predicate { $0.normalizedName == normalizedName })
            guard try context.fetchCount(sameName) == 0 else { return .duplicateName }

            context.insert(SavedErrand(draft: draft))
            try context.save()
            return .added
        } catch {
            Logger.data.error("Errand could not be saved: \(error.localizedDescription, privacy: .public)")
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
            Logger.data.error("Errand deletion could not be saved: \(error.localizedDescription, privacy: .public)")
        }
    }
}
