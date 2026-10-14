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
        #expect(model.makeErrand()?.openingMinute == 9 * 60)
        #expect(model.makeErrand()?.closingMinute == 17 * 60)
    }

    @Test func rejectsClosingBeforeOpening() {
        let model = filledModel()
        model.closing = Melbourne.date(minute: 8 * 60, on: model.opening)

        #expect(model.hoursMessage != nil)
        #expect(!model.canSave)
    }

    @Test func rejectsDurationLongerThanOpeningHours() {
        let model = filledModel()
        model.opening = Melbourne.date(minute: 9 * 60, on: model.opening)
        model.closing = Melbourne.date(minute: 9 * 60 + 30, on: model.opening)
        model.durationMinutes = 45

        #expect(model.durationMessage != nil)
        #expect(!model.canSave)
    }

    @Test func fillsTheFormFromAnErrand() {
        let errand = SavedErrand(name: "Library", place: place, durationMinutes: 30, openingMinute: 10 * 60, closingMinute: 18 * 60)

        let model = ErrandFormModel(errand: errand)

        #expect(model.name == "Library")
        #expect(model.place == place)
        #expect(model.durationMinutes == 30)
        #expect(model.openingMinute == 10 * 60)
        #expect(model.closingMinute == 18 * 60)
        #expect(model.canSave)
    }

    @Test func fillsTheFormFromADescription() {
        let model = ErrandFormModel()

        // What the on-device model might read in "post office, about 12 minutes, open 9 till midnight".
        model.fill(name: "Post office", durationMinutes: 12, openingHour: 9, closingHour: 30)

        #expect(model.name == "Post office")
        #expect(model.durationMinutes == 10)
        #expect(model.openingMinute == 9 * 60)
        #expect(model.closingMinute == 23 * 60)
        #expect(model.hoursMessage == nil)
    }

    private func filledModel() -> ErrandFormModel {
        let model = ErrandFormModel()
        model.name = "Library"
        model.place = place
        return model
    }
}
