import SwiftUI

// Sheet to add an errand; Save stays disabled until every field is valid.
struct ErrandFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ErrandStore.self) private var store
    @State private var model = ErrandFormModel()
    @State private var saveErrorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $model.name)
                        .textInputAutocapitalization(.words)
                } header: {
                    Text("Errand")
                } footer: {
                    ValidationMessage(text: model.duplicateNameMessage)
                }

                Section("Place") {
                    NavigationLink {
                        PlaceSearchView { place in model.place = place }
                    } label: {
                        PlaceLabel(place: model.place, placeholder: "Choose a place")
                    }
                }

                Section {
                    Stepper(value: $model.durationMinutes, in: 5...120, step: 5) {
                        LabeledContent("Duration", value: "\(model.durationMinutes) min")
                    }
                } footer: {
                    ValidationMessage(text: model.durationMessage)
                }

                Section {
                    DatePicker("Opens", selection: $model.opening, displayedComponents: .hourAndMinute)
                    DatePicker("Closes", selection: $model.closing, displayedComponents: .hourAndMinute)
                } header: {
                    Text("Opening Hours")
                } footer: {
                    ValidationMessage(text: model.hoursMessage)
                }

                if let saveErrorMessage {
                    Section {
                        ValidationMessage(text: "The errand couldn't be saved. \(saveErrorMessage)")
                    }
                }
            }
            .environment(\.timeZone, Melbourne.timeZone)
            .navigationTitle("New Errand")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(!model.canSave)
                }
            }
        }
    }

    private func save() {
        guard let errand = model.makeErrand() else { return }
        switch store.add(errand) {
        case .added:
            dismiss()
        case .duplicateName:
            model.showDuplicateName()
        case .failed(let error):
            saveErrorMessage = error.localizedDescription
        }
    }
}
