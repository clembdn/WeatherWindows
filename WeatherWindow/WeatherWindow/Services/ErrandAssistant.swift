//
//  ErrandAssistant.swift
//  WeatherWindow
//
//  Created by Clement Boudon on 14/10/2026.
//

import Foundation
import FoundationModels

@available(iOS 26, *)
@Generable
nonisolated struct ErrandDraft {
    @Guide(description: "Short name of the errand, for example Post office or Coles")
    var name: String
    @Guide(description: "Shop, place or address to search for in Melbourne")
    var placeQuery: String
    @Guide(description: "Minutes needed at the place; 15 if the sentence does not say", .range(5...120))
    var durationMinutes: Int
    @Guide(description: "Opening hour on a 24-hour clock; 9 if the sentence does not say", .range(0...22))
    var openingHour: Int
    @Guide(description: "Closing hour on a 24-hour clock; 17 if the sentence does not say", .range(1...23))
    var closingHour: Int
}

@available(iOS 26, *)
enum ErrandAssistant {
    static var isAvailable: Bool {
        SystemLanguageModel.default.isAvailable
    }

    static func draft(from sentence: String) async throws -> ErrandDraft {
        let session = LanguageModelSession(instructions: """
            You read one short sentence describing an errand in Melbourne and give its details. \
            Hours use a 24-hour clock: "5pm" is 17.
            """)
        return try await session.respond(to: sentence, generating: ErrandDraft.self).content
    }
}
