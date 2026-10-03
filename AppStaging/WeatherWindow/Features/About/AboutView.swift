import SwiftUI

/// Identity, data credits and settings.
struct AboutView: View {
    @AppStorage(SettingsKey.paceFactor) private var paceFactor = 1.0
    @AppStorage(AppMode.replayKey) private var replaySetting = false

    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(short) (\(build))"
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("WeatherWindow")
                            .font(.title2.bold())
                        Text("Version \(version)")
                            .foregroundStyle(.secondary)
                        Text("WeatherWindow picks the order and departure time of your errands so the walks between them stay as dry as possible.")
                    }
                    .padding(.vertical, 4)
                }

                Section("Author") {
                    LabeledContent("Name", value: "Clement Boudon")
                    LabeledContent("Student ID", value: "37465848")
                    Text("FIT3178 iOS App Development, Monash University, Semester 2 2026")
                }

                Section {
                    LabeledContent("Walking pace", value: paceFactor.formatted(.number.precision(.fractionLength(2))) + "×")
                    Slider(value: $paceFactor, in: 0.8...1.3, step: 0.05) {
                        Text("Walking pace")
                    } minimumValueLabel: {
                        Text("Faster")
                    } maximumValueLabel: {
                        Text("Slower")
                    }
                } header: {
                    Text("Settings")
                } footer: {
                    Text("Apple Maps assumes a fixed walking speed. Move right if you usually walk slower.")
                }

                Section {
                    Toggle("Replay a recorded rainy morning", isOn: $replaySetting)
                } footer: {
                    Text("Uses the radar and forecast recorded on 3 October 2026 with a frozen clock, and straight-line walking times. Works offline.")
                }

                Section("Data") {
                    Link("Weather: Open-Meteo (CC BY 4.0)", destination: URL(string: "https://open-meteo.com")!)
                    Link("Radar: RainViewer", destination: URL(string: "https://www.rainviewer.com/api.html")!)
                    Link("Maps and walking times: Apple Maps", destination: URL(string: "https://www.apple.com/maps/")!)
                }

                Section("Methods") {
                    ForEach(Self.references, id: \.title) { reference in
                        Link(destination: reference.url) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(reference.title)
                                Text(reference.use)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Section {
                    Text("Patterns from the FIT3178 labs: navigation and forms (Lab 3), SwiftData and networking (Lab 5), tabs and typed errors (Week 6), MapKit and Core Location (Lab 7), Swift Charts (Lab 9).")
                    Text("No third-party libraries. Radar images are decoded with the system zlib.")
                    Text("Generative AI (Claude, Anthropic) helped design and write parts of the code, tests and documentation. Every file was reviewed, run and can be explained by the author.")
                } header: {
                    Text("Course Materials and AI")
                }

                Section("Developer") {
                    NavigationLink("Walking times and forecast") {
                        DebugView()
                    }
                }
            }
            .replayBanner()
            .navigationTitle("About")
        }
    }

    private struct Reference {
        let title: String
        let use: String
        let url: URL
    }

    private static let references = [
        Reference(title: "Germann & Zawadzki (2002), Monthly Weather Review",
                  use: "Extrapolating radar echoes and how fast predictability is lost",
                  url: URL(string: "https://doi.org/10.1175/1520-0493(2002)130%3C2859:SDOTPO%3E2.0.CO;2")!),
        Reference(title: "Pulkkinen et al. (2019), pysteps, Geoscientific Model Development",
                  use: "Reference design for motion estimation and nowcast verification",
                  url: URL(string: "https://doi.org/10.5194/gmd-12-4185-2019")!),
        Reference(title: "Staniforth & Côté (1991), Monthly Weather Review",
                  use: "Semi-Lagrangian (backward) advection",
                  url: URL(string: "https://doi.org/10.1175/1520-0493(1991)119%3C2206:SLISFA%3E2.0.CO;2")!),
        Reference(title: "Marshall & Palmer (1948), Journal of Meteorology",
                  use: "Reflectivity to rain rate: Z = 200 R^1.6",
                  url: URL(string: "https://doi.org/10.1175/1520-0469(1948)005%3C0165:TDORWS%3E2.0.CO;2")!),
        Reference(title: "Wilks (2019), Statistical Methods in the Atmospheric Sciences",
                  use: "Critical Success Index and persistence as the baseline to beat",
                  url: URL(string: "https://doi.org/10.1016/C2017-0-03921-6")!)
    ]
}
