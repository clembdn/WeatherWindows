import Foundation

// The errand form: its values and validation rules, kept out of the view so they can be tested.
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

    // Empty for a new errand (open 9:00–17:00), or filled with the values of the errand being edited.
    init(errand: SavedErrand? = nil, day: Date = .now) {
        opening = Melbourne.date(minute: errand?.openingMinute ?? 9 * 60, on: day)
        closing = Melbourne.date(minute: errand?.closingMinute ?? 17 * 60, on: day)
        if let errand {
            name = errand.name
            place = Place(name: errand.placeName, location: errand.location)
            durationMinutes = errand.durationMinutes
        }
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

    // Values read from a sentence by the on-device model, brought back into the ranges of the form.
    func fill(name: String, durationMinutes: Int, openingHour: Int, closingHour: Int) {
        self.name = name
        self.durationMinutes = min(120, max(5, Int((Double(durationMinutes) / 5).rounded()) * 5))
        opening = Melbourne.date(minute: min(22, max(0, openingHour)) * 60, on: opening)
        closing = Melbourne.date(minute: min(23, max(1, closingHour)) * 60, on: opening)
    }

    func showDuplicateName() {
        duplicateNameMessage = "You already have an errand called “\(trimmedName)”."
    }
}
