import Foundation
import CoreLocation

struct Station: Codable, Identifiable, Equatable, Hashable {
    let id: String
    let name: String
    let latitude: Double?
    let longitude: Double?

    var coordinate: CLLocationCoordinate2D? {
        guard let lat = latitude, let lon = longitude else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    var location: CLLocation? {
        guard let lat = latitude, let lon = longitude else { return nil }
        return CLLocation(latitude: lat, longitude: lon)
    }
}

struct TransitLine: Codable, Identifiable, Equatable, Hashable {
    let id: String
    let name: String

    var displayName: String {
        name.isEmpty ? id : name
    }
}

struct ConfiguredRoute: Codable, Identifiable, Equatable {
    let id: UUID
    let name: String
    let operatorId: String
    let lineId: String
    let originStation: Station

    init(id: UUID = UUID(), name: String, operatorId: String, lineId: String, originStation: Station) {
        self.id = id
        self.name = name
        self.operatorId = operatorId
        self.lineId = lineId
        self.originStation = originStation
    }
}
