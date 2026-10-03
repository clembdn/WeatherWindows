import MapKit
import WeatherWindowCore

/// Live place suggestions around Melbourne while the user types, then the chosen place's coordinates.
@Observable
final class PlaceSearchService: NSObject {
    struct Suggestion: Identifiable, Hashable {
        let id: Int
        let title: String
        let subtitle: String
    }

    enum Status: Equatable {
        case idle
        case searching
        case results
        case noResults
        case failed(String)
    }

    var query = "" {
        didSet { search(for: query) }
    }
    private(set) var suggestions: [Suggestion] = []
    private(set) var status = Status.idle

    @ObservationIgnored private let completer = MKLocalSearchCompleter()
    @ObservationIgnored private var completions: [MKLocalSearchCompletion] = []

    private static let melbourne = MKCoordinateRegion(
        center: GeoPoint.melbourneCBD.coordinate,
        latitudinalMeters: 40_000,
        longitudinalMeters: 40_000
    )

    override init() {
        super.init()
        completer.delegate = self
        completer.region = Self.melbourne
        completer.resultTypes = [.pointOfInterest, .address]
    }

    private func search(for query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            completer.cancel()
            completions = []
            suggestions = []
            status = .idle
            return
        }
        status = .searching
        completer.queryFragment = trimmed
    }

    /// Resolves a suggestion into a name and coordinates.
    func place(for suggestion: Suggestion) async throws -> Place {
        guard completions.indices.contains(suggestion.id) else { throw ServiceError.placeNotFound }
        let request = MKLocalSearch.Request(completion: completions[suggestion.id])
        request.region = Self.melbourne

        do {
            let response = try await MKLocalSearch(request: request).start()
            guard let item = response.mapItems.first else { throw ServiceError.placeNotFound }
            return Place(name: item.name ?? suggestion.title, location: GeoPoint(item.placemark.coordinate))
        } catch {
            throw ServiceError(error)
        }
    }
}

extension PlaceSearchService: MKLocalSearchCompleterDelegate {
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        completions = completer.results
        suggestions = completions.enumerated().map { index, completion in
            Suggestion(id: index, title: completion.title, subtitle: completion.subtitle)
        }
        status = suggestions.isEmpty ? .noResults : .results
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: any Error) {
        let serviceError = ServiceError(error)
        completions = []
        suggestions = []
        status = serviceError == .placeNotFound ? .noResults : .failed(serviceError.errorDescription ?? "")
    }
}
