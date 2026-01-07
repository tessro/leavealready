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

    func findNearestRoute(from routes: [ConfiguredRoute]) -> ActiveRoute? {
        guard let location = currentLocation, !routes.isEmpty else { return nil }

        var nearestRoute: ConfiguredRoute?
        var nearestDistance: CLLocationDistance = .infinity
        var isReversed = false

        for route in routes {
            let originDistance = location.distance(from: route.originStation.location)
            let destDistance = location.distance(from: route.destinationStation.location)

            if originDistance < nearestDistance {
                nearestDistance = originDistance
                nearestRoute = route
                isReversed = false
            }

            if destDistance < nearestDistance {
                nearestDistance = destDistance
                nearestRoute = route
                isReversed = true
            }
        }

        guard let route = nearestRoute else { return nil }
        return ActiveRoute(route: route, isReversed: isReversed)
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
