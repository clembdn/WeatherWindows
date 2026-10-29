//
//  ErrandFormView.swift
//  WeatherWindow
//
//  Created by Clement Boudon on 7/10/2026.
//

import SwiftUI
import FoundationModels

struct ErrandFormView: View {
    let errand: SavedErrand?

    @Environment(\.dismiss) private var dismiss
    @Environment(ErrandStore.self) private var store
    @State private var model: ErrandFormModel
    @State private var saveErrorMessage: String?
    @State private var confirmsDiscard = false

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
                        .foregroundStyle(.secondaryText)
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
                        .foregroundStyle(.secondaryText)
                } footer: {
                    ValidationMessage(text: model.placeMessage)
                }

                Section {
                    Stepper(value: $model.durationMinutes, in: 5...120, step: 5) {
                        LabeledContent("Duration", value: "\(model.durationMinutes) min")
                    }
                    .accessibilityLabel("Duration")
                    .accessibilityValue("\(model.durationMinutes) minutes")
                } footer: {
                    ValidationMessage(text: model.durationMessage)
                }

                Section {
                    DatePicker("Opens", selection: $model.opening, displayedComponents: .hourAndMinute)
                    DatePicker("Closes", selection: $model.closing, displayedComponents: .hourAndMinute)
                } header: {
                    Text("Opening Hours")
                        .foregroundStyle(.secondaryText)
                } footer: {
                    ValidationMessage(text: model.hoursMessage)
                }

                if !plans.isEmpty {
                    Section {
                        ForEach(plans) { plan in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(plan.departure.formatted(date: .abbreviated, time: .shortened))
                                Text(plan.orderedStops.map(\.name).joined(separator: " → "))
                                    .font(.caption)
                                    .foregroundStyle(.secondaryText)
                            }
                        }
                    } header: {
                        Text("Used in Plans")
                            .foregroundStyle(.secondaryText)
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
            .interactiveDismissDisabled(model.hasChanges)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: cancel)
                        .confirmationDialog("Discard your changes?", isPresented: $confirmsDiscard, titleVisibility: .visible) {
                            Button("Discard Changes", role: .destructive) { dismiss() }
                            Button("Keep Editing", role: .cancel) {}
                        }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(!model.canSave)
                        .accessibilityHint(model.canSave ? "" : "Something is missing: each field says what to fix under it.")
                }
            }
        }
    }

    private func cancel() {
        if model.hasChanges {
            confirmsDiscard = true
        } else {
            dismiss()
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
    @Bindable var model: ErrandFormModel
    @State private var isFilling = false
    @State private var errorMessage: String?

    var body: some View {
        Section {
            TextField("Post office, 10 min, open 9 to 5", text: $model.sentence, axis: .vertical)
                // The placeholder is an example, not a name for the field.
                .accessibilityLabel("Errand description")
                .accessibilityHint("For example: post office, 10 min, open 9 to 5.")
            Button("Fill In the Form", systemImage: "sparkles", action: fillIn)
                .disabled(model.sentence.trimmingCharacters(in: .whitespaces).isEmpty || isFilling)
                .accessibilityHint("Fills in the name, place, duration and opening hours from your sentence.")
            if isFilling {
                ProgressView("Reading your sentence…")
            }
            ValidationMessage(text: errorMessage)
        } header: {
            Text("Describe It")
                .foregroundStyle(.secondaryText)
        } footer: {
            if ErrandAssistant.isAvailable {
                Text("Apple Intelligence fills in the form on your iPhone. Check every field before saving.")
                    .foregroundStyle(.secondaryText)
            } else {
                Text("Apple Intelligence isn't available, so the form is filled from the numbers in your sentence. Check every field before saving.")
                    .foregroundStyle(.secondaryText)
            }
        }
    }

    private func fillIn() {
        isFilling = true
        errorMessage = nil
        Task {
            defer { isFilling = false }
            model.fill(fromSentence: model.sentence)
            var placeQuery = model.name
            if ErrandAssistant.isAvailable {
                do {
                    let draft = try await ErrandAssistant.draft(from: model.sentence)
                    model.fill(name: draft.name, durationMinutes: draft.durationMinutes,
                               openingHour: draft.openingHour, closingHour: draft.closingHour)
                    placeQuery = draft.placeQuery
                } catch let error as LanguageModelSession.GenerationError {
                    errorMessage = switch error {
                    case .assetsUnavailable:
                        "Apple Intelligence is still downloading. The form was filled from the numbers in your sentence."
                    case .unsupportedLanguageOrLocale:
                        "Apple Intelligence doesn't support this language. The form was filled from the numbers in your sentence."
                    case .guardrailViolation, .refusal:
                        "Apple Intelligence couldn't read this sentence. The form was filled from the numbers in it."
                    default:
                        "Apple Intelligence is unavailable right now. The form was filled from the numbers in your sentence."
                    }
                } catch {
                    errorMessage = "Apple Intelligence is unavailable right now. The form was filled from the numbers in your sentence."
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
