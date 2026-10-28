//
//  DebugView.swift
//  WeatherWindow
//
//  Created by Clement Boudon on 7/10/2026.
//

import SwiftData
import SwiftUI

struct DebugView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \SavedErrand.name) private var errands: [SavedErrand]
    @AppStorage("paceFactor") private var paceFactor = 1.0
    @State private var matrixState = LoadState<DirectionsService.WalkingMatrix>.idle
    @State private var forecastState = LoadState<[ForecastHour]>.idle

    private var stops: [Stop] {
        errands.prefix(4).map { $0.makeStop() }
    }

    var body: some View {
        List {
            Section {
                switch matrixState {
                case .idle, .loading:
                    ProgressView("Asking Apple Maps…")
                case .loaded(let matrix):
                    let pairs = PlanRequest.neededPairs(for: stops)
                    LabeledContent("From cache", value: "\(matrix.fromCache)")
                    LabeledContent("Requested", value: "\(matrix.requested)")
                    ForEach(pairs.indices, id: \.self) { index in
                        let pair = pairs[index]
                        let seconds = matrix.times[pair.from]?[pair.to] ?? 0
                        LabeledContent("\(name(of: pair.from)) → \(name(of: pair.to))",
                                       value: "\(Int((seconds / 60).rounded())) min")
                    }
                case .failed(let error):
                    ErrorRow(error: error) {
                        Task { await loadMatrix() }
                    }
                }
            } header: {
                Text("Walking times · start and end at Melbourne CBD")
                    .foregroundStyle(.secondaryText)
            } footer: {
                Text("Uses your first four errands. Pace factor \(paceFactor.formatted(.number.precision(.fractionLength(2))))×.")
                    .foregroundStyle(.secondaryText)
            }

            Section {
                switch forecastState {
                case .idle, .loading:
                    ProgressView("Loading forecast…")
                case .loaded(let hours):
                    ForEach(hours, id: \.time) { hour in
                        LabeledContent("\(Melbourne.time(hour.time.addingTimeInterval(-3600)))–\(Melbourne.time(hour.time))",
                                       value: "\(Int(hour.precipitationProbability)) % · \(hour.precipitation.formatted()) mm")
                    }
                case .failed(let error):
                    ErrorRow(error: error) {
                        Task { await loadForecast() }
                    }
                }
            } header: {
                Text("Hourly forecast · centre of your errands")
                    .foregroundStyle(.secondaryText)
            }
        }
        .navigationTitle("Debug")
        .task {
            await loadMatrix()
            await loadForecast()
        }
    }

    private func loadMatrix() async {
        matrixState = .loading
        do {
            let directions = DirectionsService(context: context, paceFactor: paceFactor)
            matrixState = .loaded(try await directions.walkingMatrix(start: .melbourneCBD, end: .melbourneCBD, stops: stops))
        } catch {
            matrixState = .failed(ServiceError(error))
        }
    }

    private func loadForecast() async {
        forecastState = .loading
        let centre = GeoPoint.centroid(of: stops.map(\.location)) ?? .melbourneCBD
        do {
            forecastState = .loaded(try await OpenMeteoService().hourlyForecast(at: centre))
        } catch {
            forecastState = .failed(ServiceError(error))
        }
    }

    private func name(of waypoint: Waypoint) -> String {
        switch waypoint {
        case .start: "Start"
        case .end: "End"
        case .stop(let id): stops.first { $0.id == id }?.name ?? "?"
        }
    }
}
