import MapKit
import OSLog
import WeatherWindowCore

/// The real walking path for display; the solver itself only uses straight lines.
struct RouteService {
    /// Apple Maps' walking polyline, or a straight line if no route can be found.
    func walkingLine(from origin: GeoPoint, to destination: GeoPoint) async -> [GeoPoint] {
        guard origin != destination else { return [origin, destination] }

        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: origin.coordinate))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destination.coordinate))
        request.transportType = .walking

        do {
            guard let polyline = try await MKDirections(request: request).calculate().routes.first?.polyline else {
                return [origin, destination]
            }
            var coordinates = [CLLocationCoordinate2D](repeating: kCLLocationCoordinate2DInvalid, count: polyline.pointCount)
            polyline.getCoordinates(&coordinates, range: NSRange(location: 0, length: polyline.pointCount))
            return coordinates.map(GeoPoint.init)
        } catch {
            Logger.network.info("Walking route unavailable, drawing a straight line: \(error.localizedDescription, privacy: .public)")
            return [origin, destination]
        }
    }
}
