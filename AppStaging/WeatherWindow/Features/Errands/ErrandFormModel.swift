import Foundation

/// The new-errand form's values and validation rules, kept out of the view so they can be tested.
@Observable
final class ErrandFormModel {
    var name = "" {
        didSet { duplicateNameMessage = nil }
    }
    var place: Place?
    var durationMinutes = 15
    var opening: Date
    var closing: Date
    var duplicateNameMessage: String?

    static let durationRange = 5...120
    static let durationStep = 5

    init(day: Date = .now) {
        opening = AppClock.date(minute: 9 * 60, on: day)
        closing = AppClock.date(minute: 17 * 60, on: day)
    }

    var openingMinute: Int { AppClock.minute(of: opening) }
    var closingMinute: Int { AppClock.minute(of: closing) }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var hoursMessage: String? {
        closingMinute <= openingMinute ? "Closing time must be after opening time." : nil
    }

    var durationMessage: String? {
        guard hoursMessage == nil, durationMinutes > closingMinute - openingMinute else { return nil }
        return "This errand takes longer than the place is open."
    }

    var canSave: Bool {
        !trimmedName.isEmpty && place != nil && hoursMessage == nil && durationMessage == nil
            && duplicateNameMessage == nil
    }

    var draft: ErrandDraft? {
        guard canSave, let place else { return nil }
        return ErrandDraft(
            name: trimmedName,
            place: place,
            durationMinutes: durationMinutes,
            openingMinute: openingMinute,
            closingMinute: closingMinute
        )
    }

    func showDuplicateName() {
        duplicateNameMessage = "You already have an errand called “\(trimmedName)”."
    }
}
