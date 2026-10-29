//
//  VerificationView.swift
//  WeatherWindow
//
//  Created by Clement Boudon on 14/10/2026.
//

import Charts
import SwiftData
import SwiftUI

struct VerificationView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: [SortDescriptor(\VerificationScore.date, order: .reverse), SortDescriptor(\VerificationScore.leadMinutes)])
    private var savedScores: [VerificationScore]
    @AppStorage("replayMode") private var replayMode = false
    @State private var model = VerificationViewModel()
    @State private var lastSource = VerificationSource.recordedDay

    private var runs: [[VerificationScore]] {
        var runs: [[VerificationScore]] = []
        for score in savedScores {
            if let first = runs.last?.first, first.date == score.date {
                runs[runs.count - 1].append(score)
            } else {
                runs.append([score])
            }
        }
        return runs
    }

    private var isLoading: Bool {
        if case .loading = model.state {
            return true
        }
        return false
    }

    var body: some View {
        List {
            Section {
                Button("Score the Rainy Day of 3 October", systemImage: "cloud.rain") {
                    score(.recordedDay)
                }
                .accessibilityHint("Compares the nowcast with the radar images recorded that day.")
                if !replayMode {
                    Button("Score the Last 2 Hours", systemImage: "dot.radiowaves.left.and.right") {
                        score(.lastTwoHours)
                    }
                    .accessibilityHint("Downloads the last 2 hours of radar images and compares the nowcast with them.")
                }
                if isLoading {
                    ProgressView(model.progress ?? "Reading the radar images…")
                }
                if case .failed(let error) = model.state {
                    ErrorRow(error: error) { score(lastSource) }
                }
            } footer: {
                Text("From each radar image, the nowcast moves the rain along its measured motion, while persistence assumes the rain stays where it is. "
                     + "Both are compared with the image seen 10, 20 and 30 minutes later, within about 46 km of the CBD.")
                    .foregroundStyle(.secondaryText)
            }
            .disabled(isLoading)

            if let latest = runs.first {
                Section {
                    ScoreChart(scores: latest)
                        .padding(.vertical, 8)
                    ForEach(latest) { score in
                        ScoreRow(score: score)
                    }
                } header: {
                    Text(latest.first?.source ?? "Latest Run")
                        .foregroundStyle(.secondaryText)
                } footer: {
                    Text("Critical Success Index: places where rain was both predicted and seen, divided by places where it was predicted or seen. 1 is perfect.")
                        .foregroundStyle(.secondaryText)
                }
            }

            if runs.count > 1 {
                Section {
                    ForEach(1..<runs.count, id: \.self) { index in
                        let run = runs[index]
                        VStack(alignment: .leading, spacing: 4) {
                            Text(run.first?.source ?? "")
                                .font(.headline)
                            Text(run.first?.date.formatted(date: .abbreviated, time: .shortened) ?? "")
                                .font(.caption)
                                .foregroundStyle(.secondaryText)
                            ForEach(run) { score in
                                ScoreRow(score: score)
                            }
                        }
                    }
                } header: {
                    Text("Earlier Runs")
                        .foregroundStyle(.secondaryText)
                }
            }
        }
        .navigationTitle("Nowcast Accuracy")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func score(_ source: VerificationSource) {
        lastSource = source
        Task {
            await model.score(source, context: context)
        }
    }
}

private struct ScoreChart: View {
    let scores: [VerificationScore]

    var body: some View {
        Chart {
            ForEach(scores) { score in
                if let csi = score.nowcastCSI {
                    BarMark(x: .value("Lead time", "\(score.leadMinutes) min"), y: .value("CSI", csi))
                        .foregroundStyle(by: .value("Method", "Nowcast"))
                        .position(by: .value("Method", "Nowcast"))
                        .accessibilityLabel("\(score.leadMinutes) minutes ahead, nowcast")
                        .accessibilityValue(ScoreRow.text(csi))
                }
                if let csi = score.persistenceCSI {
                    BarMark(x: .value("Lead time", "\(score.leadMinutes) min"), y: .value("CSI", csi))
                        .foregroundStyle(by: .value("Method", "Persistence"))
                        .position(by: .value("Method", "Persistence"))
                        .accessibilityLabel("\(score.leadMinutes) minutes ahead, persistence")
                        .accessibilityValue(ScoreRow.text(csi))
                }
            }
        }
        .chartYScale(domain: 0...1)
        .chartYAxisLabel("CSI")
        .frame(minHeight: 200)
    }
}

private struct ScoreRow: View {
    let score: VerificationScore

    static func text(_ value: Double?) -> String {
        guard let value else { return "no rain" }
        return value.formatted(.number.precision(.fractionLength(2)))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(score.leadMinutes) min ahead · \(score.cases) forecasts")
                .font(.subheadline.weight(.semibold))
            Text("Nowcast \(Self.text(score.nowcastCSI)) · Persistence \(Self.text(score.persistenceCSI))")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondaryText)
        }
        .accessibilityElement(children: .combine)
    }
}
