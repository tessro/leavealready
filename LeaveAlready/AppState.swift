import Foundation
import Combine

class AppState: ObservableObject {
    @Published var settings = SettingsManager.shared
    @Published var locationManager = LocationManager()
    @Published var transitService = TransitService()
    @Published var activeRoute: ConfiguredRoute?
    @Published var showSettings = false

    private var cancellables = Set<AnyCancellable>()
    private var lastRefreshTime: Date?

    init() {
        // When location updates, find nearest route
        locationManager.$currentLocation
            .compactMap { $0 }
            .sink { [weak self] _ in
                self?.updateActiveRoute()
            }
            .store(in: &cancellables)

        // When routes change, update active route
        settings.$routes
            .sink { [weak self] _ in
                self?.updateActiveRoute()
            }
            .store(in: &cancellables)
    }

    func updateActiveRoute() {
        activeRoute = locationManager.findNearestRoute(from: settings.routes)
    }

    func refresh() {
        lastRefreshTime = Date()
        locationManager.requestLocation()

        if let route = activeRoute {
            Task {
                await transitService.fetchDepartures(for: route)
            }
        }
    }

    /// Refreshes only if 30+ seconds have passed since the last refresh
    func refreshIfNeeded() {
        let threshold: TimeInterval = 30
        if let lastRefresh = lastRefreshTime,
           Date().timeIntervalSince(lastRefresh) < threshold {
            return
        }
        refresh()
    }

    func fetchDepartures() {
        guard let route = activeRoute else { return }
        Task {
            await transitService.fetchDepartures(for: route)
        }
    }
}
