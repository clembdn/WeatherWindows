import SwiftData
import SwiftUI
import UIKit

/// "Leave now or wait?" for the next walk, with the radar collision view and its time scrubber.
struct NextWalkView: View {
    @Environment(\.modelContext) private var context
    @Environment(LocationService.self) private var location
    @Environment(NotificationService.self) private var notifications
    @Environment(\.openURL) private var openURL
    @AppStorage(SettingsKey.paceFactor) private var paceFactor = 1.0
    @AppStorage(AppMode.replayKey) private var replaySetting = false
    @State private var model: NextWalkViewModel
    @State private var reminderMessage: String?

    init(input: NextWalkInput) {
        _model = State(initialValue: NextWalkViewModel(input: input))
    }

    private var services: PlanServices {
        PlanServices.current(isReplay: AppMode.isReplay(setting: replaySetting),
                             context: context, location: location, paceFactor: paceFactor)
    }

    var body: some View {
        List {
            switch model.state {
            case .idle, .loading:
                ProgressView("Checking the radar…")
            case .failed(let error):
                ErrorRow(error: error) { Task { await model.load(services: services) } }
            case .loaded(let result):
                Section {
                    DepartureAdviceCard(result: result, reminderMessage: reminderMessage) { date in
                        Task { await remind(at: date) }
                    }
                    if notifications.isDenied {
                        Button("Turn On Notifications in Settings", systemImage: "gear") {
                            if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                        }
                    }
                }

                if let notice = result.radarNotice {
                    Section {
                        Label(notice, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.secondary)
                    }
                }

                if let nowcast = result.nowcast {
                    Section {
                        CollisionView(result: result, nowcast: nowcast, minuteOffset: model.minuteOffset)
                            .listRowInsets(EdgeInsets())
                        TimeScrubber(minuteOffset: $model.minuteOffset, now: result.now,
                                     lastObservation: nowcast.lastObservation)
                    } header: {
                        Text("Rain and Your Route")
                    } footer: {
                        Text("Left of now: radar images. Right of now: extrapolated rain, paler as it gets less certain. Orange dot: you.")
                    }
                }
            }
        }
        .navigationTitle("Next Walk")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            while !Task.isCancelled {
                await model.load(services: services)
                try? await Task.sleep(for: .seconds(10 * 60))
            }
        }
    }

    private func remind(at date: Date) async {
        let scheduled = await notifications.scheduleReminder(
            id: "next-walk-\(model.input.current.name)",
            at: date,
            title: "Time to go",
            body: "Leave \(model.input.current.name) now for a drier walk."
        )
        reminderMessage = scheduled
            ? "Reminder set for \(AppClock.time(date))."
            : "Notifications are off, so no reminder was set."
    }
}

/// Minutes from now on the collision view, from −30 (observed) to +30 (predicted).
struct TimeScrubber: View {
    @Binding var minuteOffset: Double
    let now: Date
    let lastObservation: Date

    private var label: String {
        let time = now.addingTimeInterval(minuteOffset * 60)
        return AppClock.time(time) + (time <= lastObservation ? " · observed" : " · predicted")
    }

    var body: some View {
        VStack(alignment: .leading) {
            Text(label)
                .font(.subheadline.monospacedDigit())
            Slider(value: $minuteOffset, in: -30...30, step: 1) {
                Text("Time")
            } minimumValueLabel: {
                Text("−30")
            } maximumValueLabel: {
                Text("+30")
            }
            .accessibilityValue(label)
        }
    }
}
