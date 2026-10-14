import Foundation
import SwiftData

// How well the nowcast and persistence predicted the rain at one lead time, during one scoring run.
@Model
final class VerificationScore {
    var date: Date
    var source: String
    var leadMinutes: Int
    var cases: Int
    // Nil when there was no rain to score.
    var nowcastCSI: Double?
    var persistenceCSI: Double?

    init(date: Date, source: String, leadMinutes: Int, cases: Int, nowcastCSI: Double?, persistenceCSI: Double?) {
        self.date = date
        self.source = source
        self.leadMinutes = leadMinutes
        self.cases = cases
        self.nowcastCSI = nowcastCSI
        self.persistenceCSI = persistenceCSI
    }
}
