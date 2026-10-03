import Foundation
import Testing
import WeatherWindowCore
@testable import WeatherWindow

struct ErrandFormModelTests {
    private let place = Place(name: "State Library Victoria", location: GeoPoint(latitude: -37.8098, longitude: 144.9652))

    @Test func needsANameAndAPlace() {
        let model = ErrandFormModel()
        #expect(!model.canSave)

        model.name = "Library"
        #expect(!model.canSave)

        model.place = place
        #expect(model.canSave)
        #expect(model.draft?.openingMinute == 9 * 60)
        #expect(model.draft?.closingMinute == 17 * 60)
    }

    @Test func rejectsClosingBeforeOpening() {
        let model = filledModel()
        model.closing = AppClock.date(minute: 8 * 60, on: model.opening)

        #expect(model.hoursMessage != nil)
        #expect(!model.canSave)
    }

    @Test func rejectsDurationLongerThanOpeningHours() {
        let model = filledModel()
        model.opening = AppClock.date(minute: 9 * 60, on: model.opening)
        model.closing = AppClock.date(minute: 9 * 60 + 30, on: model.opening)
        model.durationMinutes = 45

        #expect(model.durationMessage != nil)
        #expect(!model.canSave)
    }

    @Test func duplicateMessageClearsWhenNameChanges() {
        let model = filledModel()
        model.showDuplicateName()
        #expect(!model.canSave)

        model.name = "Library 2"
        #expect(model.duplicateNameMessage == nil)
        #expect(model.canSave)
    }

    @Test func trimsTheName() {
        let model = filledModel()
        model.name = "  Library  "
        #expect(model.draft?.name == "Library")
    }

    private func filledModel() -> ErrandFormModel {
        let model = ErrandFormModel()
        model.name = "Library"
        model.place = place
        return model
    }
}
