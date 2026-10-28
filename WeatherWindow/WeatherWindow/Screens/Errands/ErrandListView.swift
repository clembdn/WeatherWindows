//
//  ErrandListView.swift
//  WeatherWindow
//
//  Created by Clement Boudon on 7/10/2026.
//

import SwiftData
import SwiftUI

struct ErrandListView: View {
    @Environment(ErrandStore.self) private var store
    @Query(sort: \SavedErrand.name) private var errands: [SavedErrand]
    @State private var searchText = ""
    @State private var isAddingErrand = false
    @State private var editedErrand: SavedErrand?

    private var visibleErrands: [SavedErrand] {
        let query = SavedErrand.normalize(searchText)
        if query.isEmpty {
            return errands
        }
        return errands.filter { errand in
            errand.normalizedName.contains(query) || SavedErrand.normalize(errand.placeName).contains(query)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if errands.isEmpty {
                    ContentUnavailableView {
                        Label("No Errands Yet", systemImage: "checklist")
                    } description: {
                        Text("Add the post office, the supermarket, the library…")
                    } actions: {
                        Button("Add Errand") { isAddingErrand = true }
                            .buttonStyle(.borderedProminent)
                            .tint(.buttonBlue)
                    }
                } else {
                    List {
                        ForEach(visibleErrands) { errand in
                            Button {
                                editedErrand = errand
                            } label: {
                                ErrandRow(errand: errand)
                            }
                            .tint(.primary)
                        }
                        .onDelete(perform: deleteErrands)
                    }
                    .overlay {
                        if visibleErrands.isEmpty {
                            ContentUnavailableView.search(text: searchText)
                        }
                    }
                    .searchable(text: $searchText, prompt: "Search")
                }
            }
            .navigationTitle("Errands")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Add Errand", systemImage: "plus") { isAddingErrand = true }
                }
            }
            .sheet(isPresented: $isAddingErrand) {
                ErrandFormView()
            }
            .sheet(item: $editedErrand) { errand in
                ErrandFormView(errand: errand)
            }
        }
    }

    private func deleteErrands(at offsets: IndexSet) {
        let shown = visibleErrands
        store.delete(offsets.map { shown[$0] })
    }
}

private struct ErrandRow: View {
    let errand: SavedErrand

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(errand.name)
                .font(.headline)
            Text(errand.placeName)
                .font(.subheadline)
                .foregroundStyle(.secondaryText)
            Label("\(errand.durationMinutes) min · open \(Melbourne.time(minute: errand.openingMinute))–\(Melbourne.time(minute: errand.closingMinute))",
                  systemImage: "clock")
                .font(.caption)
                .foregroundStyle(.secondaryText)
        }
        .accessibilityElement(children: .combine)
    }
}
