//
//  AboutView.swift
//  WeatherWindow
//
//  Created by Clement Boudon on 7/10/2026.
//

import SwiftUI

struct AboutView: View {
    @AppStorage("paceFactor") private var paceFactor = 1.0
    @AppStorage("replayMode") private var replayMode = false
    @AppStorage("usesEnsemble") private var usesEnsemble = false

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
                    Toggle("Use the 40-run ensemble forecast", isOn: $usesEnsemble)
                } footer: {
                    Text("Scores plans against five runs of the Open-Meteo ensemble, from the driest to the wettest, instead of shifting one forecast 15 and 30 minutes. Not used in replay mode.")
                }

                Section {
                    Toggle("Replay a recorded rainy morning", isOn: $replayMode)
                } footer: {
                    Text("Uses the radar and forecast recorded on 3 October 2026 with a frozen clock, and straight-line walking times. Works offline.")
                }

                Section {
                    NavigationLink("How Accurate Is the Nowcast?") {
                        VerificationView()
                    }
                } footer: {
                    Text("Replays recorded radar images and compares the nowcast with what the radar saw next.")
                }

                Section("Data") {
                    Link("Weather: Open-Meteo (CC BY 4.0)", destination: URL(string: "https://open-meteo.com")!)
                    Link("Radar: RainViewer", destination: URL(string: "https://www.rainviewer.com/api.html")!)
                    Link("Maps and walking times: Apple Maps", destination: URL(string: "https://www.apple.com/maps/")!)
                }

                Section("Methods") {
                    Link("Germann & Zawadzki (2002): extrapolating radar echoes",
                         destination: URL(string: "https://doi.org/10.1175/1520-0493(2002)130%3C2859:SDOTPO%3E2.0.CO;2")!)
                    Link("Pulkkinen et al. (2019), pysteps: motion estimation and verification",
                         destination: URL(string: "https://doi.org/10.5194/gmd-12-4185-2019")!)
                    Link("Staniforth & Côté (1991): semi-Lagrangian advection",
                         destination: URL(string: "https://doi.org/10.1175/1520-0493(1991)119%3C2206:SLISFA%3E2.0.CO;2")!)
                    Link("Marshall & Palmer (1948): reflectivity to rain rate, Z = 200 R^1.6",
                         destination: URL(string: "https://doi.org/10.1175/1520-0469(1948)005%3C0165:TDORWS%3E2.0.CO;2")!)
                    Link("Wilks (2019): Critical Success Index and persistence",
                         destination: URL(string: "https://doi.org/10.1016/C2017-0-03921-6")!)
                }

                Section("Course Materials and AI") {
                    Text("Patterns from the FIT3178 labs: navigation and forms (Lab 3), SwiftData and networking (Lab 5), tabs and typed errors (Week 6), MapKit and Core Location (Lab 7), Swift Charts (Lab 9).")
                    Text("No third-party libraries. Radar images are decoded with the system zlib.")
                    Text("Generative AI (Claude, Anthropic) helped design and write parts of the code, tests and documentation. Every file was reviewed, run and can be explained by the author.")
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
