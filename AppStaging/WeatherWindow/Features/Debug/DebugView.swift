import ForecastKit
import SolverKit
import SwiftData
import SwiftUI
import WeatherWindowCore

/// Shows the real data the solver will use: the walking-time matrix and the 48-hour forecast.
struct DebugView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \SavedErrand.createdAt) private var errands: [SavedErrand]
    @AppStorage(SettingsKey.paceFactor) private var paceFactor = 1.0
    @State private var matrixState = LoadState<WalkingMatrixBuilder.Result>.idle
    @State private var forecastState = LoadState<[WeatherSample]>.idle
    @State private var stops: [Stop] = []

    var body: some View {
        List {
            Section {
                switch matrixState {
                case .idle, .loading:
                    ProgressView("Asking Apple Maps…")
                case .loaded(let result):
                    LabeledContent("From cache", value: "\(result.cachedCount)")
                    LabeledContent("Requested", value: "\(result.requestedCount)")
                    ForEach(rows(for: result)) { row in
                        LabeledContent(row.id, value: row.minutes)
                    }
                case .failed(let error):
                    ErrorRow(error: error) { Task { await loadMatrix() } }
                }
            } header: {
                Text("Walking times · start and end at Melbourne CBD")
            } footer: {
                Text("Uses your first four errands. Pace factor \(paceFactor.formatted(.number.precision(.fractionLength(2))))×.")
            }

            Section("Hourly forecast · centre of your errands") {
                switch forecastState {
                case .idle, .loading:
                    ProgressView("Loading forecast…")
                case .loaded(let samples):
                    ForEach(samples, id: \.time) { sample in
                        LabeledContent(AppClock.time(sample.time.addingTimeInterval(-3600)) + "–" + AppClock.time(sample.time)) {
                            Text("\(Int(sample.precipitationProbability)) % · \(sample.precipitation.formatted()) mm · w \(sample.rainWeight.formatted(.number.precision(.fractionLength(2))))")
                        }
                    }
                case .failed(let error):
                    ErrorRow(error: error) { Task { await loadForecast() } }
                }
            }
        }
        .navigationTitle("Debug")
        .task {
            stops = errands.prefix(4).map { $0.makeStop() }
            async let matrix: Void = loadMatrix()
            async let forecast: Void = loadForecast()
            _ = await (matrix, forecast)
        }
    }

    private func loadMatrix() async {
        matrixState = .loading
        do {
            let builder = WalkingMatrixBuilder(context: context, paceFactor: paceFactor)
            matrixState = .loaded(try await builder.walkingTimes(start: .melbourneCBD, end: .melbourneCBD, stops: stops))
        } catch is CancellationError {
            return
        } catch {
            matrixState = .failed(ServiceError(error))
        }
    }

    private func loadForecast() async {
        forecastState = .loading
        let centre = GeoPoint.centroid(of: stops.map(\.location)) ?? .melbourneCBD
        do {
            forecastState = .loaded(try await OpenMeteoService().hourlyForecast(at: centre))
        } catch is CancellationError {
            return
        } catch {
            forecastState = .failed(ServiceError(error))
        }
    }

    private struct MatrixRow: Identifiable {
        let id: String
        let minutes: String
    }

    private func rows(for result: WalkingMatrixBuilder.Result) -> [MatrixRow] {
        WalkingMatrixBuilder.edges(for: stops).map { from, to in
            let seconds = result.walkingTimes[from]?[to] ?? 0
            return MatrixRow(id: "\(name(of: from)) → \(name(of: to))", minutes: "\(Int((seconds / 60).rounded())) min")
        }
    }

    private func name(of node: Node) -> String {
        switch node {
        case .start: "Start"
        case .end: "End"
        case .stop(let id): stops.first { $0.id == id }?.name ?? "?"
        }
    }
}

/// An error message with a Retry button.
struct ErrorRow: View {
    let error: ServiceError
    let retry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(error.errorDescription ?? "Something went wrong.", systemImage: "exclamationmark.triangle")
            Button("Retry", action: retry)
                .buttonStyle(.bordered)
        }
    }
}
