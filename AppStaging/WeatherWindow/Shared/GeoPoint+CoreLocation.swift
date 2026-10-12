import CoreLocation
import WeatherWindowCore

extension GeoPoint {
    static let melbourneCBD = GeoPoint(latitude: -37.8136, longitude: 144.9631)

    init(_ coordinate: CLLocationCoordinate2D) {
        self.init(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
