import SwiftUI

/// Sheet to add an errand; Save stays disabled until every field is valid.
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
                        if let place = model.place {
                            Label(place.name, systemImage: "mappin.and.ellipse")
                        } else {
                            Text("Choose a place")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section {
                    Stepper(value: $model.durationMinutes, in: ErrandFormModel.durationRange, step: ErrandFormModel.durationStep) {
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
            }
            .environment(\.timeZone, AppClock.timeZone)
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
            .alert("Couldn't Save Errand", isPresented: .init(
                get: { saveErrorMessage != nil },
                set: { if !$0 { saveErrorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(saveErrorMessage ?? "")
            }
        }
    }

    private func save() {
        guard let draft = model.draft else { return }
        switch store.add(draft) {
        case .added:
            dismiss()
        case .duplicateName:
            model.showDuplicateName()
        case .failed(let error):
            saveErrorMessage = error.localizedDescription
        }
    }
}

/// A field's error under it: icon and text, never colour alone.
struct ValidationMessage: View {
    let text: String?

    var body: some View {
        if let text {
            Label(text, systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
        }
    }
}
