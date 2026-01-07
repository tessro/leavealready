import Foundation
import CoreLocation
import Combine

class LocationManager: NSObject, ObservableObject {
    private let locationManager = CLLocationManager()

    @Published var currentLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var errorMessage: String?

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func requestPermission() {
        locationManager.requestWhenInUseAuthorization()
    }

    func requestLocation() {
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            requestPermission()
            return
        }
        locationManager.requestLocation()
    }

    func findNearestRoute(from routes: [ConfiguredRoute]) -> ConfiguredRoute? {
        guard !routes.isEmpty else { return nil }

        // If no location available, return the first route
        guard let location = currentLocation else {
            return routes[0]
        }

        var nearestRoute: ConfiguredRoute?
        var nearestDistance: CLLocationDistance = .infinity

        for route in routes {
            if let originLocation = route.originStation.location {
                let distance = location.distance(from: originLocation)
                if distance < nearestDistance {
                    nearestDistance = distance
                    nearestRoute = route
                }
            }
        }

        // If no route with coordinates found, use first route
        return nearestRoute ?? routes[0]
    }
}

extension LocationManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        currentLocation = locations.last
        errorMessage = nil
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        errorMessage = error.localizedDescription
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus

        if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            locationManager.requestLocation()
        }
    }
}
