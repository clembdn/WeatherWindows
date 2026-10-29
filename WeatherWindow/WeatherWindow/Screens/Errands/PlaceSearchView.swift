//
//  PlaceSearchView.swift
//  WeatherWindow
//
//  Created by Clement Boudon on 7/10/2026.
//

import MapKit
import SwiftUI

struct PlaceSearchView: View {
    let onSelect: (Place) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var search = PlaceSearchService()
    @State private var isResolving = false
    @State private var errorMessage: String?

    var body: some View {
        List {
            if isResolving {
                ProgressView("Finding the place…")
            }
            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.errorRed)
            }

            if let message = search.errorMessage {
                Label(message, systemImage: "wifi.exclamationmark")
                    .foregroundStyle(.secondaryText)
            } else if search.query.isEmpty {
                Text("Type a shop, a library or an address in Melbourne.")
                    .foregroundStyle(.secondaryText)
            } else if search.results.isEmpty && search.isSearching {
                ProgressView("Searching…")
            } else if search.results.isEmpty {
                ContentUnavailableView.search(text: search.query)
            }

            ForEach(search.results, id: \.self) { completion in
                Button {
                    select(completion)
                } label: {
                    VStack(alignment: .leading) {
                        Text(completion.title)
                            .foregroundStyle(.primary)
                        if !completion.subtitle.isEmpty {
                            Text(completion.subtitle)
                                .font(.subheadline)
                                .foregroundStyle(.secondaryText)
                        }
                    }
                }
                .disabled(isResolving)
            }
        }
        .navigationTitle("Choose Place")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $search.query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search Melbourne")
        .onSubmit(of: .search) {
            select(nil)
        }
    }

    private func select(_ completion: MKLocalSearchCompletion?) {
        guard !isResolving else { return }
        isResolving = true
        errorMessage = nil
        Task {
            defer { isResolving = false }
            do {
                let place: Place
                if let completion {
                    place = try await search.place(for: completion)
                } else {
                    place = try await search.placeForQuery()
                }
                onSelect(place)
                dismiss()
            } catch {
                let message = ServiceError(error).errorDescription ?? "The place couldn't be found."
                errorMessage = message
                Announcer.say(message)
            }
        }
    }
}
