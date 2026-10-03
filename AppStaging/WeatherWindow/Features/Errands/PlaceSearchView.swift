import SwiftUI

/// Live place suggestions; empty, offline and error states appear in the list, never as alerts.
struct PlaceSearchView: View {
    let onSelect: (Place) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var search = PlaceSearchService()
    @State private var resolvingID: Int?
    @State private var resolveErrorMessage: String?

    var body: some View {
        List {
            if let resolveErrorMessage {
                Label(resolveErrorMessage, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
            }

            statusRow

            ForEach(search.suggestions) { suggestion in
                Button {
                    Task { await select(suggestion) }
                } label: {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(suggestion.title)
                                .foregroundStyle(.primary)
                            if !suggestion.subtitle.isEmpty {
                                Text(suggestion.subtitle)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        if resolvingID == suggestion.id {
                            ProgressView()
                        }
                    }
                }
                .disabled(resolvingID != nil)
            }
        }
        .navigationTitle("Choose Place")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $search.query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search Melbourne")
    }

    @ViewBuilder private var statusRow: some View {
        switch search.status {
        case .idle:
            Text("Type a shop, a library or an address in Melbourne.")
                .foregroundStyle(.secondary)
        case .searching:
            if search.suggestions.isEmpty {
                HStack {
                    ProgressView()
                    Text("Searching…")
                }
            }
        case .noResults:
            ContentUnavailableView.search(text: search.query)
        case .failed(let message):
            Label(message, systemImage: "wifi.exclamationmark")
                .foregroundStyle(.secondary)
        case .results:
            EmptyView()
        }
    }

    private func select(_ suggestion: PlaceSearchService.Suggestion) async {
        resolvingID = suggestion.id
        resolveErrorMessage = nil
        defer { resolvingID = nil }

        do {
            onSelect(try await search.place(for: suggestion))
            dismiss()
        } catch is CancellationError {
            return
        } catch {
            resolveErrorMessage = ServiceError(error).errorDescription
        }
    }
}
