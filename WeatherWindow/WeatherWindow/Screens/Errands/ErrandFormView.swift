//
//  ErrandFormView.swift
//  WeatherWindow
//
//  Created by Clement Boudon on 7/10/2026.
//

import SwiftUI

struct ErrandFormView: View {
    let errand: SavedErrand?

    @Environment(\.dismiss) private var dismiss
    @Environment(ErrandStore.self) private var store
    @State private var model: ErrandFormModel
    @State private var saveErrorMessage: String?

    init(errand: SavedErrand? = nil) {
        self.errand = errand
        _model = State(initialValue: ErrandFormModel(errand: errand))
    }

    var body: some View {
        NavigationStack {
            Form {
                if errand == nil {
                    if #available(iOS 26, *) {
                        DescribeErrandSection(model: model)
                    }
                }

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
            .navigationTitle(errand == nil ? "New Errand" : "Edit Errand")
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
        guard let edited = model.makeErrand() else { return }
        let result: SaveErrandResult
        if let errand {
            result = store.update(errand, with: edited)
        } else {
            result = store.add(edited)
        }
        switch result {
        case .saved:
            dismiss()
        case .duplicateName:
            model.showDuplicateName()
        case .failed(let error):
            saveErrorMessage = error.localizedDescription
        }
    }
}

@available(iOS 26, *)
private struct DescribeErrandSection: View {
    let model: ErrandFormModel
    @State private var sentence = ""
    @State private var isFilling = false
    @State private var errorMessage: String?

    var body: some View {
        if ErrandAssistant.isAvailable {
            Section {
                TextField("Post office, 10 min, open 9 to 5", text: $sentence, axis: .vertical)
                Button("Fill In the Form", systemImage: "sparkles", action: fillIn)
                    .disabled(sentence.trimmingCharacters(in: .whitespaces).isEmpty || isFilling)
                if isFilling {
                    ProgressView("Reading your sentence…")
                }
                ValidationMessage(text: errorMessage)
            } header: {
                Text("Describe It")
            } footer: {
                Text("Apple Intelligence fills in the form on your iPhone. Check every field before saving.")
            }
        }
    }

    private func fillIn() {
        isFilling = true
        errorMessage = nil
        Task {
            defer { isFilling = false }
            do {
                let draft = try await ErrandAssistant.draft(from: sentence)
                model.fill(name: draft.name, durationMinutes: draft.durationMinutes,
                           openingHour: draft.openingHour, closingHour: draft.closingHour)
                let search = PlaceSearchService()
                search.query = draft.placeQuery
                do {
                    model.place = try await search.placeForQuery()
                } catch {
                    errorMessage = "“\(draft.placeQuery)” wasn't found. Choose the place below."
                }
            } catch {
                errorMessage = "That sentence couldn't be read. Fill in the form instead."
            }
        }
    }
}
