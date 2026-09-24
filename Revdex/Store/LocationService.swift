import CoreLocation
import SwiftUI

/// Asks for location on first run and turns a fix into a city name, so captures
/// are tagged and the local board works without the player typing anything.
@MainActor
final class LocationService: NSObject, ObservableObject {

    @Published private(set) var status: CLAuthorizationStatus
    @Published private(set) var city: String?
    /// Last known fix, attached to captures so they can be mapped.
    @Published private(set) var coordinate: CLLocationCoordinate2D?

    /// Read by the store when a catch is recorded.
    static private(set) var lastCoordinate: CLLocationCoordinate2D?

    private let manager = CLLocationManager()
    private var resolving = false

    /// Set once so a city the player typed by hand is never overwritten.
    var onResolve: ((String) -> Void)?

    override init() {
        status = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    /// Called as soon as the app is on screen.
    func request() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.startUpdatingLocation()
        default:
            break
        }
    }

    private func resolve(_ location: CLLocation) {
        guard !resolving else { return }
        resolving = true
        Task {
            defer { resolving = false }
            let places = try? await CLGeocoder().reverseGeocodeLocation(location)
            guard let place = places?.first else { return }
            let name = place.locality ?? place.subAdministrativeArea ?? place.administrativeArea
            guard let name else { return }
            city = name.uppercased()
            onResolve?(name.uppercased())
        }
    }
}

extension LocationService: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            self.status = manager.authorizationStatus
            if self.status == .authorizedWhenInUse || self.status == .authorizedAlways {
                manager.startUpdatingLocation()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let last = locations.last else { return }
        Task { @MainActor in
            self.coordinate = last.coordinate
            LocationService.lastCoordinate = last.coordinate
            self.resolve(last)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) { }
}
