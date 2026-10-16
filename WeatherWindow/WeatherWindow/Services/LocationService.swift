//
//  LocationService.swift
//  WeatherWindow
//
//  Created by Clement Boudon on 7/10/2026.
//

import CoreLocation

final class LocationService: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<GeoPoint, Error>?
    private var timeoutTask: Task<Void, Never>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
    }

    func currentLocation() async throws -> GeoPoint {
        if continuation != nil {
            throw ServiceError.locationUnavailable
        }
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            handleAuthorization(manager.authorizationStatus)
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard continuation != nil else { return }
        handleAuthorization(manager.authorizationStatus)
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last, location.horizontalAccuracy >= 0 else { return }
        finish(with: .success(GeoPoint(location.coordinate)))
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if let error = error as? CLError {
            if error.code == .locationUnknown {
                return
            }
            if error.code == .denied {
                finish(with: .failure(ServiceError.locationDenied))
                return
            }
        }
        finish(with: .failure(ServiceError.locationUnavailable))
    }

    private func handleAuthorization(_ status: CLAuthorizationStatus) {
        switch status {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            startUpdates()
        case .denied, .restricted:
            finish(with: .failure(ServiceError.locationDenied))
        @unknown default:
            finish(with: .failure(ServiceError.locationUnavailable))
        }
    }

    private func startUpdates() {
        guard timeoutTask == nil else { return }
        manager.startUpdatingLocation()
        timeoutTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(15))
            guard !Task.isCancelled else { return }
            self?.finish(with: .failure(ServiceError.locationUnavailable))
        }
    }

    private func finish(with result: Result<GeoPoint, Error>) {
        manager.stopUpdatingLocation()
        timeoutTask?.cancel()
        timeoutTask = nil
        continuation?.resume(with: result)
        continuation = nil
    }
}
