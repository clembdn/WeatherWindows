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

    private var plans: [DayPlan] {
        let found = errand?.plannedStops.compactMap(\.plan) ?? []
        return found.sorted { $0.departure > $1.departure }
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
                    ValidationMessage(text: model.nameMessage)
                }

                Section {
                    NavigationLink {
                        PlaceSearchView { place in model.place = place }
                    } label: {
                        PlaceLabel(place: model.place, placeholder: "Choose a place")
                    }
                } header: {
                    Text("Place")
                } footer: {
                    ValidationMessage(text: model.placeMessage)
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

                if !plans.isEmpty {
                    Section("Used in Plans") {
                        ForEach(plans) { plan in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(plan.departure.formatted(date: .abbreviated, time: .shortened))
                                Text(plan.orderedStops.map(\.name).joined(separator: " → "))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
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
            if ErrandAssistant.isAvailable {
                Text("Apple Intelligence fills in the form on your iPhone. Check every field before saving.")
            } else {
                Text("Apple Intelligence isn't available, so the form is filled from the numbers in your sentence. Check every field before saving.")
            }
        }
    }

    private func fillIn() {
        isFilling = true
        errorMessage = nil
        Task {
            defer { isFilling = false }
            model.fill(fromSentence: sentence)
            var placeQuery = model.name
            if ErrandAssistant.isAvailable {
                do {
                    let draft = try await ErrandAssistant.draft(from: sentence)
                    model.fill(name: draft.name, durationMinutes: draft.durationMinutes,
                               openingHour: draft.openingHour, closingHour: draft.closingHour)
                    placeQuery = draft.placeQuery
                } catch {
                    errorMessage = "Apple Intelligence failed: \(error.localizedDescription)"
                }
            }
            let search = PlaceSearchService()
            search.query = placeQuery
            do {
                model.place = try await search.placeForQuery()
            } catch {
                errorMessage = "“\(placeQuery)” wasn't found. Choose the place below."
            }
        }
    }
}
