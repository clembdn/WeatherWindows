//
//  NextWalkView.swift
//  WeatherWindow
//
//  Created by Clement Boudon on 7/10/2026.
//

import SwiftUI

struct NextWalkView: View {
    let data: any PlanDataSource

    @Environment(NotificationService.self) private var notifications
    @State private var model: NextWalkViewModel
    @State private var reminderMessage: String?
    @State private var showsMap = true

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

                Section {
                    Toggle("Alert Me If Rain Is Coming", isOn: $model.alertsWhenRainComes)
                } footer: {
                    Text("While this screen is open, the radar is checked every 10 minutes and you get a notification when rain heads for your next walk.")
                        .foregroundStyle(.secondaryText)
                }

                if let notice = result.radarNotice {
                    Section {
                        Label(notice, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.secondaryText)
                    }
                }

                if let nowcast = result.nowcast {
                    Section {
                        Picker("View", selection: $showsMap) {
                            Text("Map").tag(true)
                            Text("Radar Grid").tag(false)
                        }
                        .pickerStyle(.segmented)
                        CollisionView(result: result, nowcast: nowcast, minuteOffset: $model.minuteOffset, showsMap: showsMap,
                                      data: data)
                            .listRowInsets(EdgeInsets())
                        TimeSlider(minuteOffset: $model.minuteOffset, now: result.now, lastObservation: nowcast.lastObservation)
                    } header: {
                        Text("Rain and Your Route")
                            .foregroundStyle(.secondaryText)
                    } footer: {
                        Text("Left of now: radar images. Right of now: extrapolated rain, paler as it gets less certain. Orange dot: you. The radar grid also works offline.")
                            .foregroundStyle(.secondaryText)
                    }
                }
            }
        }
        .onChange(of: model.alertsWhenRainComes) {
            Task { await sendRainAlert() }
        }
        .navigationTitle("Next Walk")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            while !Task.isCancelled {
                await model.load(data: data)
                await sendRainAlert()
                try? await Task.sleep(for: .seconds(10 * 60))
            }
        }
    }

    private func sendRainAlert() async {
        if let alert = model.rainAlert() {
            await notifications.alertNow(id: "rain-alert", body: alert)
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
            HStack {
                Text("−30")
                Slider(value: $minuteOffset, in: -30...30, step: 1) {
                    Text("Time")
                }
                .accessibilityValue(label)
                Text("+30")
            }
        }
    }
}
