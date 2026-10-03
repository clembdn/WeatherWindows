import OSLog
import SwiftData
import SwiftUI

/// The Plan tab: choose errands, start, end and departure window, then calculate.
struct DayPlanView: View {
    @Environment(\.modelContext) private var context
    @Environment(LocationService.self) private var location
    @Query(sort: \SavedErrand.name) private var errands: [SavedErrand]
    @Query(sort: \DayPlan.date, order: .reverse) private var savedPlans: [DayPlan]
    @AppStorage(SettingsKey.paceFactor) private var paceFactor = 1.0
    @AppStorage(AppMode.replayKey) private var replaySetting = false
    @State private var model = DayPlanViewModel()
    @State private var path = NavigationPath()

    private var selectedErrands: [SavedErrand] {
        errands.filter(model.isSelected)
    }

    var body: some View {
        NavigationStack(path: $path) {
            Form {
                errandsSection
                startSection
                endSection
                windowSection
                errorSection
                savedPlansSection
            }
            .safeAreaInset(edge: .bottom) {
                calculateBar
            }
            .environment(\.timeZone, AppClock.timeZone)
            .navigationTitle("Plan")
            .navigationDestination(for: PlanRoute.self) { route in
                destination(for: route)
            }
            .navigationDestination(for: DayPlan.self) { plan in
                SavedPlanView(plan: plan)
            }
            .onChange(of: AppMode.isReplay(setting: replaySetting), initial: true) { _, isReplay in
                model = DayPlanViewModel(now: AppMode.now(isReplay: isReplay))
            }
        }
    }

    // MARK: Sections

    private var errandsSection: some View {
        Section {
            if errands.isEmpty {
                Text("Add errands in the Errands tab first.")
                    .foregroundStyle(.secondary)
            }
            ForEach(errands) { errand in
                let isSelected = model.isSelected(errand)
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
                            Text("\(errand.durationMinutes) min · open \(AppClock.string(minute: errand.openingMinute))–\(AppClock.string(minute: errand.closingMinute))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
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
            Picker("Start", selection: $model.startChoice) {
                Text("Current Location").tag(StartChoice.currentLocation)
                Text("Choose Place").tag(StartChoice.place)
            }
            .pickerStyle(.segmented)

            if model.startChoice == .place {
                NavigationLink {
                    PlaceSearchView { model.startPlace = $0 }
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
                    PlaceSearchView { model.endPlace = $0 }
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

    /// Always visible at the bottom, so "Calculate" never hides below the form.
    private var calculateBar: some View {
        Button {
            Task { await calculate() }
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

    @ViewBuilder private var errorSection: some View {
        if case .failed(let error) = model.state {
            Section {
                ErrorRow(error: error) { Task { await calculate() } }
            }
        }
    }

    @ViewBuilder private var savedPlansSection: some View {
        if !savedPlans.isEmpty {
            Section("Saved Plans") {
                ForEach(savedPlans) { plan in
                    NavigationLink(value: plan) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(plan.date.formatted(date: .abbreviated, time: .shortened))
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

    // MARK: Actions

    @ViewBuilder private func destination(for route: PlanRoute) -> some View {
        if let result = model.result {
            switch route {
            case .results:
                ResultsView(result: result)
            case .itinerary(let id):
                if let schedule = result.schedule(withID: id) {
                    ItineraryView(model: model, result: result, schedule: schedule)
                }
            }
        }
    }

    private func calculate() async {
        let services = PlanServices.current(isReplay: AppMode.isReplay(setting: replaySetting),
                                            context: context, location: location, paceFactor: paceFactor)
        await model.calculate(errands: selectedErrands, services: services)
        if model.result != nil {
            path.append(PlanRoute.results)
        }
    }

    private func deletePlans(at offsets: IndexSet) {
        for index in offsets {
            context.delete(savedPlans[index])
        }
        do {
            try context.save()
        } catch {
            Logger.data.error("Plan deletion could not be saved: \(error.localizedDescription, privacy: .public)")
        }
    }
}

/// A chosen place, or a placeholder inviting the user to choose one.
struct PlaceLabel: View {
    let place: Place?
    let placeholder: String

    var body: some View {
        if let place {
            Label(place.name, systemImage: "mappin.and.ellipse")
        } else {
            Text(placeholder)
                .foregroundStyle(.secondary)
        }
    }
}
