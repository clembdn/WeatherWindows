import NowcastKit
import SwiftUI

// "Leave now or wait?" for the next walk, with the radar collision view and its time slider.
struct NextWalkView: View {
    let data: any PlanDataSource

    @Environment(NotificationService.self) private var notifications
    @State private var model: NextWalkViewModel
    @State private var reminderMessage: String?

    init(input: NextWalkInput, data: any PlanDataSource) {
        self.data = data
        _model = State(initialValue: NextWalkViewModel(input: input))
    }

    var body: some View {
        List {
            switch model.state {
            case .idle, .loading:
                ProgressView("Checking the radar…")
            case .failed(let error):
                ErrorRow(error: error) {
                    Task { await model.load(data: data) }
                }
            case .loaded(let result):
                Section {
                    DepartureAdviceCard(result: result, reminderMessage: reminderMessage) { date in
                        remind(at: date)
                    }
                    if notifications.isDenied {
                        NotificationSettingsButton()
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
                        TimeSlider(minuteOffset: $model.minuteOffset, now: result.now, lastObservation: nowcast.lastObservation)
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
            // New radar images arrive every 10 minutes; the loop stops when the screen goes away.
            while !Task.isCancelled {
                await model.load(data: data)
                try? await Task.sleep(for: .seconds(10 * 60))
            }
        }
    }

    private func remind(at date: Date) {
        Task {
            reminderMessage = await notifications.scheduleReminder(
                id: "next-walk-\(model.input.current.name)",
                at: date,
                body: "Leave \(model.input.current.name) now for a drier walk."
            )
        }
    }
}

// Minutes from now on the collision view: −30 shows radar images, +30 the extrapolated rain.
private struct TimeSlider: View {
    @Binding var minuteOffset: Double
    let now: Date
    let lastObservation: Date

    private var label: String {
        let time = now.addingTimeInterval(minuteOffset * 60)
        return Melbourne.time(time) + (time <= lastObservation ? " · observed" : " · predicted")
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
