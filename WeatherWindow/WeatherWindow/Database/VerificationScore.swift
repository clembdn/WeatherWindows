//
//  VerificationScore.swift
//  WeatherWindow
//
//  Created by Clement Boudon on 14/10/2026.
//

import Foundation
import SwiftData

@Model
final class VerificationScore {
    var date: Date
    var source: String
    var leadMinutes: Int
    var cases: Int
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
