import SwiftUI

/// Identity, data credits and settings.
struct AboutView: View {
    @AppStorage(SettingsKey.paceFactor) private var paceFactor = 1.0

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

                Section("Data") {
                    Link("Weather: Open-Meteo (CC BY 4.0)", destination: URL(string: "https://open-meteo.com")!)
                    Link("Radar: RainViewer", destination: URL(string: "https://www.rainviewer.com/api.html")!)
                    Link("Maps and walking times: Apple Maps", destination: URL(string: "https://www.apple.com/maps/")!)
                }

                Section("Developer") {
                    NavigationLink("Walking times and forecast") {
                        DebugView()
                    }
                }
            }
            .navigationTitle("About")
        }
    }
}
