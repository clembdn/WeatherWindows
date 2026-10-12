import OSLog
import SwiftData
import SwiftUI

private let logger = Logger(subsystem: "edu.monash.cboudon.WeatherWindow", category: "data")

// The Plan tab: choose errands, start, end and departure window, then calculate.
struct DayPlanView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \SavedErrand.name) private var errands: [SavedErrand]
    @Query(sort: \DayPlan.departure, order: .reverse) private var savedPlans: [DayPlan]
    @AppStorage("paceFactor") private var paceFactor = 1.0
    @AppStorage("replayMode") private var replayMode = false
    @State private var model = DayPlanViewModel()
    @State private var location = LocationService()
    @State private var showsResults = false

    private var selectedErrands: [SavedErrand] {
        errands.filter { model.selectedIDs.contains($0.id) }
    }

    // Live services, or the recorded morning in replay mode.
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
                if case .failed(let error) = model.state {
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
                // The app may have stayed open: never offer a window that has already started.
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
                    .foregroundStyle(.secondary)
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
                        VStack(alignment: .leading, spacing: 2) {
                            Text(errand.name)
                                .foregroundStyle(.primary)
                            Text("\(errand.durationMinutes) min · open \(Melbourne.time(minute: errand.openingMinute))–\(Melbourne.time(minute: errand.closingMinute))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .tint(.primary)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
                .accessibilityIdentifier("errand-\(errand.name)")
            }
        } header: {
            Text("Errands · \(selectedErrands.count) of \(DayPlanViewModel.maxErrands)")
        } footer: {
            ValidationMessage(text: model.selectionMessage)
        }
    }

    private var startSection: some View {
        Section("Start") {
            Picker("Start", selection: $model.startsAtCurrentLocation) {
                Text("Current Location").tag(true)
                Text("Choose Place").tag(false)
            }
            .pickerStyle(.segmented)

            if !model.startsAtCurrentLocation {
                NavigationLink {
                    PlaceSearchView { place in model.startPlace = place }
                } label: {
                    PlaceLabel(place: model.startPlace, placeholder: "Choose a start place")
                }
            }
        }
    }

    private var endSection: some View {
        Section("End") {
            Toggle("Return to start", isOn: $model.endsAtStart)
            if !model.endsAtStart {
                NavigationLink {
                    PlaceSearchView { place in model.endPlace = place }
                } label: {
                    PlaceLabel(place: model.endPlace, placeholder: "Choose where you finish")
                }
            }
        }
    }

    private var windowSection: some View {
        Section {
            DatePicker("Earliest departure", selection: $model.windowStart, displayedComponents: .hourAndMinute)
            DatePicker("Latest departure", selection: $model.windowEnd, displayedComponents: .hourAndMinute)
        } header: {
            Text("Departure Window")
        } footer: {
            if let message = model.windowMessage {
                ValidationMessage(text: message)
            } else {
                Text("Every departure in this window is tried, 5 minutes apart.")
            }
        }
    }

    // Always visible at the bottom, so "Calculate" never hides below the form.
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
        .disabled(!model.canCalculate(selectedCount: selectedErrands.count))
        .accessibilityIdentifier("calculate")
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
    }

    @ViewBuilder private var savedPlansSection: some View {
        if !savedPlans.isEmpty {
            Section("Saved Plans") {
                ForEach(savedPlans) { plan in
                    NavigationLink {
                        SavedPlanView(plan: plan, data: data)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(plan.departure.formatted(date: .abbreviated, time: .shortened))
                            Text(plan.orderedStops.map(\.name).joined(separator: " → "))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete(perform: deletePlans)
            }
        }
    }

    private func calculate() {
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
