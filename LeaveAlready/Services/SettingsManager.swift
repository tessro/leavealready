import Foundation
import Combine

class SettingsManager: ObservableObject {
    static let shared = SettingsManager()

    private let apiKeyKey = "511_api_key"
    private let routesKey = "configured_routes"

    @Published var apiKey: String {
        didSet {
            UserDefaults.standard.set(apiKey, forKey: apiKeyKey)
        }
    }

    @Published var routes: [ConfiguredRoute] {
        didSet {
            if let encoded = try? JSONEncoder().encode(routes) {
                UserDefaults.standard.set(encoded, forKey: routesKey)
            }
        }
    }

    var hasValidConfiguration: Bool {
        !apiKey.isEmpty && !routes.isEmpty
    }

    private init() {
        self.apiKey = UserDefaults.standard.string(forKey: apiKeyKey) ?? ""

        if let data = UserDefaults.standard.data(forKey: routesKey),
           let decoded = try? JSONDecoder().decode([ConfiguredRoute].self, from: data) {
            self.routes = decoded
        } else {
            self.routes = []
        }
    }

    func addRoute(_ route: ConfiguredRoute) {
        routes.append(route)
    }

    func removeRoute(at indexSet: IndexSet) {
        routes.remove(atOffsets: indexSet)
    }

    func clearAll() {
        apiKey = ""
        routes = []
    }
}
