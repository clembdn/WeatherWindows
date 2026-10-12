import MapKit
import WeatherWindowCore

// Live place suggestions around Melbourne while the user types, then the chosen place's coordinates.
@Observable
final class PlaceSearchService: NSObject, MKLocalSearchCompleterDelegate {
    var query = "" {
        didSet { search() }
    }
    private(set) var results: [MKLocalSearchCompletion] = []
    private(set) var isSearching = false
    private(set) var errorMessage: String?

    @ObservationIgnored private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        completer.region = MKCoordinateRegion(center: GeoPoint.melbourneCBD.coordinate,
                                              latitudinalMeters: 40_000, longitudinalMeters: 40_000)
        completer.resultTypes = [.pointOfInterest, .address]
    }

    private func search() {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        errorMessage = nil
        if text.isEmpty {
            completer.cancel()
            results = []
            isSearching = false
        } else {
            isSearching = true
            completer.queryFragment = text
        }
    }

    func place(for completion: MKLocalSearchCompletion) async throws -> Place {
        try await resolve(MKLocalSearch.Request(completion: completion), name: completion.title)
    }

    // Used when the user presses Return instead of tapping a suggestion.
    func placeForQuery() async throws -> Place {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty {
            throw ServiceError.placeNotFound
        }
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = text
        request.region = completer.region
        return try await resolve(request, name: text)
    }

    private func resolve(_ request: MKLocalSearch.Request, name: String) async throws -> Place {
        let response = try await MKLocalSearch(request: request).start()
        guard let item = response.mapItems.first else {
            throw ServiceError.placeNotFound
        }
        return Place(name: item.name ?? name, location: GeoPoint(item.placemark.coordinate))
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        results = completer.results
        isSearching = false
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        results = []
        isSearching = false
        let serviceError = ServiceError(error)
        // "Not found" just means there is no suggestion, which the list already says.
        errorMessage = serviceError == .placeNotFound ? nil : serviceError.errorDescription
    }
}
