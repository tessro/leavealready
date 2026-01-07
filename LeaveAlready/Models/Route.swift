import Foundation
import CoreLocation

struct Station: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let latitude: Double
    let longitude: Double

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var location: CLLocation {
        CLLocation(latitude: latitude, longitude: longitude)
    }
}

struct ConfiguredRoute: Codable, Identifiable, Equatable {
    let id: UUID
    let name: String
    let operatorId: String
    let lineId: String
    let originStation: Station
    let destinationStation: Station

    init(id: UUID = UUID(), name: String, operatorId: String, lineId: String, originStation: Station, destinationStation: Station) {
        self.id = id
        self.name = name
        self.operatorId = operatorId
        self.lineId = lineId
        self.originStation = originStation
        self.destinationStation = destinationStation
    }
}

struct ActiveRoute {
    let route: ConfiguredRoute
    let isReversed: Bool

    var departureStation: Station {
        isReversed ? route.destinationStation : route.originStation
    }

    var arrivalStation: Station {
        isReversed ? route.originStation : route.destinationStation
    }

    var displayName: String {
        "\(departureStation.name) → \(arrivalStation.name)"
    }
}
