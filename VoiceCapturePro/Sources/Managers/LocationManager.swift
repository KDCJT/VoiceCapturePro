// LocationManager.swift
// Requests location when recording starts and reverse-geocodes to a human-readable name.

import CoreLocation
import Combine

final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {

    // MARK: Published

    @Published var currentLocation:     CLLocation?
    @Published var currentLocationName: String = "未知位置"
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined

    // MARK: Private

    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private var completionHandler: ((CLLocation?) -> Void)?

    // MARK: Init

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        authorizationStatus = manager.authorizationStatus
    }

    // MARK: Public

    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }

    /// Fetch current location once, then reverse-geocode it.
    func fetchCurrentLocation(completion: ((CLLocation?) -> Void)? = nil) {
        completionHandler = completion
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        default:
            completion?(nil)
        }
    }

    // MARK: CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        currentLocation = location
        reverseGeocode(location)
        completionHandler?(location)
        completionHandler = nil
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        completionHandler?(nil)
        completionHandler = nil
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            manager.requestLocation()
        }
    }

    // MARK: Reverse Geocoding

    private func reverseGeocode(_ location: CLLocation) {
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, _ in
            guard let placemark = placemarks?.first else { return }
            let parts = [
                placemark.locality,
                placemark.subLocality,
                placemark.thoroughfare
            ].compactMap { $0 }
            DispatchQueue.main.async {
                self?.currentLocationName = parts.joined(separator: " · ")
            }
        }
    }
}
