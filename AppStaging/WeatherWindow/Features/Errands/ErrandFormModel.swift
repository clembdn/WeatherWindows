import Foundation

// The new-errand form: its values and validation rules, kept out of the view so they can be tested.
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

    init(day: Date = .now) {
        opening = Melbourne.date(minute: 9 * 60, on: day)
        closing = Melbourne.date(minute: 17 * 60, on: day)
    }

    var openingMinute: Int { Melbourne.minute(of: opening) }
    var closingMinute: Int { Melbourne.minute(of: closing) }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var hoursMessage: String? {
        if closingMinute <= openingMinute {
            return "Closing time must be after opening time."
        }
        return nil
    }

    var durationMessage: String? {
        if hoursMessage == nil && durationMinutes > closingMinute - openingMinute {
            return "This errand takes longer than the place is open."
        }
        return nil
    }

    var canSave: Bool {
        !trimmedName.isEmpty && place != nil && hoursMessage == nil && durationMessage == nil && duplicateNameMessage == nil
    }

    func makeErrand() -> SavedErrand? {
        guard canSave, let place else { return nil }
        return SavedErrand(name: trimmedName, place: place, durationMinutes: durationMinutes,
                           openingMinute: openingMinute, closingMinute: closingMinute)
    }

    func showDuplicateName() {
        duplicateNameMessage = "You already have an errand called “\(trimmedName)”."
    }
}
