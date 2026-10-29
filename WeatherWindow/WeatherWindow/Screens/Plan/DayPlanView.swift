//
//  DayPlanView.swift
//  WeatherWindow
//
//  Created by Clement Boudon on 7/10/2026.
//

import OSLog
import SwiftData
import SwiftUI

private let logger = Logger(subsystem: "edu.monash.cboudon.WeatherWindow", category: "data")

struct DayPlanView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \SavedErrand.name) private var errands: [SavedErrand]
    @Query(sort: \DayPlan.departure, order: .reverse) private var savedPlans: [DayPlan]
    @AppStorage("paceFactor") private var paceFactor = 1.0
    @AppStorage("replayMode") private var replayMode = false
    @AppStorage("usesEnsemble") private var usesEnsemble = false
    @State private var model = DayPlanViewModel()
    @State private var location = LocationService()
    @State private var showsResults = false

    private var selectedErrands: [SavedErrand] {
        errands.filter { model.selectedIDs.contains($0.id) }
    }

    private var data: any PlanDataSource {
        if replayMode {
            return ReplayData()
        }
        return LiveData(context: context, location: location, paceFactor: paceFactor)
    }

    var body: some View {
        NavigationStack {
            Form {
                errandsSection
                startSection
                endSection
                windowSection
                if case .failed(let error) = model.state, !error.isLocationError {
                    Section {
                        ErrorRow(error: error) { calculate() }
                    }
                }
                savedPlansSection
            }
            .safeAreaInset(edge: .bottom) {
                calculateBar
            }
            .environment(\.timeZone, Melbourne.timeZone)
            .navigationTitle("Plan")
            .navigationDestination(isPresented: $showsResults) {
                if let result = model.result {
                    ResultsView(result: result)
                }
            }
            .onChange(of: errands.map(\.id)) {
                model.keepSelected(onlyAmong: errands.map(\.id))
            }
            .onChange(of: replayMode, initial: true) {
                model.resetWindow(now: data.now)
            }
            .onAppear {
                if model.windowStart < data.now {
                    model.resetWindow(now: data.now)
                }
            }
        }
    }

    private var errandsSection: some View {
        Section {
            if errands.isEmpty {
                Text("Add errands in the Errands tab first.")
                    .foregroundStyle(.secondaryText)
            }
            if !savedPlans.isEmpty {
                NavigationLink {
                    ItinerariesView { plan in model.reuse(plan) }
                } label: {
                    Label("Use a Saved Itinerary", systemImage: "arrow.clockwise")
                }
                .accessibilityHint("Selects the errands of a plan you saved before.")
                .accessibilityIdentifier("use-saved-itinerary")
            }
            ForEach(errands) { errand in
                let isSelected = model.selectedIDs.contains(errand.id)
                Button {
                    model.toggle(errand)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                            .imageScale(.large)
                            // The selected trait below says the same thing in words.
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(errand.name)
                                .foregroundStyle(.primary)
                            Text("\(errand.durationMinutes) min · open \(Melbourne.time(minute: errand.openingMinute))–\(Melbourne.time(minute: errand.closingMinute))")
                                .font(.caption)
                                .foregroundStyle(.secondaryText)
                        }
                    }
                }
                .tint(.primary)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
                .accessibilityHint(isSelected ? "Removes this errand from the plan." : "Adds this errand to the plan.")
                .accessibilityIdentifier("errand-\(errand.name)")
            }
        } header: {
            Text("Errands · \(selectedErrands.count) of \(min(errands.count, DayPlanViewModel.maxErrands))")
                .foregroundStyle(.secondaryText)
        } footer: {
            ValidationMessage(text: model.selectionMessage)
        }
    }

    private var startSection: some View {
        Section {
            Picker("Start", selection: $model.startsAtCurrentLocation) {
                Text("Current Location").tag(true)
                Text("Choose Place").tag(false)
            }
            .modifier(AdaptivePickerStyle())

            if !model.startsAtCurrentLocation {
                NavigationLink {
                    PlaceSearchView { place in model.startPlace = place }
                } label: {
                    PlaceLabel(place: model.startPlace, placeholder: "Choose a start place")
                }
            }

            if case .failed(let error) = model.state, error.isLocationError {
                ErrorRow(error: error) { calculate() }
            }
        } header: {
            Text("Start")
                .foregroundStyle(.secondaryText)
        }
    }

    private var endSection: some View {
        Section {
            Toggle("Return to start", isOn: $model.endsAtStart)
            if !model.endsAtStart {
                NavigationLink {
                    PlaceSearchView { place in model.endPlace = place }
                } label: {
                    PlaceLabel(place: model.endPlace, placeholder: "Choose where you finish")
                }
            }
        } header: {
            Text("End")
                .foregroundStyle(.secondaryText)
        }
    }

    private var windowSection: some View {
        Section {
            DatePicker("Earliest departure", selection: $model.windowStart, displayedComponents: .hourAndMinute)
            DatePicker("Latest departure", selection: $model.windowEnd, displayedComponents: .hourAndMinute)
        } header: {
            Text("Departure Window")
                .foregroundStyle(.secondaryText)
        } footer: {
            if let message = model.windowMessage {
                ValidationMessage(text: message)
            } else {
                Text("Every departure in this window is tried, 5 minutes apart.")
                    .foregroundStyle(.secondaryText)
            }
        }
    }

    private var calculateBar: some View {
        Button {
            calculate()
        } label: {
            HStack {
                if model.isLoading {
                    ProgressView()
                    Text(model.progress ?? "Calculating…")
                } else {
                    Label("Calculate", systemImage: "cloud.sun")
                }
            }
            .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.borderedProminent)
        .tint(.buttonBlue)
        .disabled(!model.canCalculate(selectedCount: selectedErrands.count))
        .accessibilityHint("Finds the order and departure time with the least rain.")
        .accessibilityIdentifier("calculate")
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
    }

    @ViewBuilder private var savedPlansSection: some View {
        if !savedPlans.isEmpty {
            Section {
                ForEach(savedPlans) { plan in
                    NavigationLink {
                        SavedPlanView(plan: plan, data: data)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(plan.departure.formatted(date: .abbreviated, time: .shortened))
                            Text(plan.orderedStops.map(\.name).joined(separator: " → "))
                                .font(.caption)
                                .foregroundStyle(.secondaryText)
                        }
                    }
                }
                .onDelete(perform: deletePlans)
            } header: {
                Text("Saved Plans")
                    .foregroundStyle(.secondaryText)
            }
        }
    }

    private func calculate() {
        model.usesEnsemble = usesEnsemble && !replayMode
        Task {
            await model.calculate(errands: selectedErrands, data: data)
            if model.result != nil {
                showsResults = true
            }
        }
    }

    private func deletePlans(at offsets: IndexSet) {
        for index in offsets {
            context.delete(savedPlans[index])
        }
        do {
            try context.save()
        } catch {
            logger.error("Plans could not be deleted: \(error.localizedDescription)")
        }
    }
}
