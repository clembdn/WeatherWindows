import SwiftData
import SwiftUI

// The errand library: search, swipe to delete, and + to add.
struct ErrandListView: View {
    @Environment(ErrandStore.self) private var store
    @Query(sort: \SavedErrand.name) private var errands: [SavedErrand]
    @State private var searchText = ""
    @State private var isAddingErrand = false

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
                    }
                } else {
                    List {
                        ForEach(visibleErrands) { errand in
                            ErrandRow(errand: errand)
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
                .foregroundStyle(.secondary)
            Label("\(errand.durationMinutes) min · open \(Melbourne.time(minute: errand.openingMinute))–\(Melbourne.time(minute: errand.closingMinute))",
                  systemImage: "clock")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}
