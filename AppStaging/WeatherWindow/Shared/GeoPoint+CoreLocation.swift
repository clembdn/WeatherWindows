import CoreLocation
import WeatherWindowCore

extension GeoPoint {
    nonisolated init(_ coordinate: CLLocationCoordinate2D) {
        self.init(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }

    nonisolated var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    /// Melbourne CBD, the default map centre and debug start point.
    nonisolated static let melbourneCBD = GeoPoint(latitude: -37.8136, longitude: 144.9631)
}

/// Keys of the values kept in `UserDefaults` through `@AppStorage`.
nonisolated enum SettingsKey {
    /// Multiplies Apple Maps walking times: 1.2 means you walk 20 % slower than Maps assumes.
    static let paceFactor = "paceFactor"
}
