import ForecastKit
import SolverKit
import SwiftData
import SwiftUI
import WeatherWindowCore

// The real data the solver uses: the walking-time matrix of the first four errands and the 48-hour forecast.
struct DebugView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \SavedErrand.name) private var errands: [SavedErrand]
    @AppStorage("paceFactor") private var paceFactor = 1.0
    @State private var matrixState = LoadState<DirectionsService.WalkingMatrix>.idle
    @State private var forecastState = LoadState<[WeatherSample]>.idle

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
            } footer: {
                Text("Uses your first four errands. Pace factor \(paceFactor.formatted(.number.precision(.fractionLength(2))))×.")
            }

            Section("Hourly forecast · centre of your errands") {
                switch forecastState {
                case .idle, .loading:
                    ProgressView("Loading forecast…")
                case .loaded(let samples):
                    ForEach(samples, id: \.time) { sample in
                        // Each Open-Meteo value is the rain of the hour that ends at `sample.time`.
                        LabeledContent("\(Melbourne.time(sample.time.addingTimeInterval(-3600)))–\(Melbourne.time(sample.time))",
                                       value: "\(Int(sample.precipitationProbability)) % · \(sample.precipitation.formatted()) mm")
                    }
                case .failed(let error):
                    ErrorRow(error: error) {
                        Task { await loadForecast() }
                    }
                }
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

    private func name(of node: Node) -> String {
        switch node {
        case .start: "Start"
        case .end: "End"
        case .stop(let id): stops.first { $0.id == id }?.name ?? "?"
        }
    }
}
