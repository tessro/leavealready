import Foundation

class TransitService: ObservableObject {
    @Published var departures: [Departure] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let settings = SettingsManager.shared
    private let baseURL = "https://api.511.org/transit"

    func fetchDepartures(for route: ConfiguredRoute) async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }

        guard !settings.apiKey.isEmpty else {
            await MainActor.run {
                errorMessage = "API key not set"
                isLoading = false
            }
            return
        }

        let stopCode = route.originStation.id
        let operatorId = route.operatorId

        guard var components = URLComponents(string: "\(baseURL)/StopMonitoring") else {
            await MainActor.run {
                errorMessage = "Invalid URL"
                isLoading = false
            }
            return
        }

        components.queryItems = [
            URLQueryItem(name: "api_key", value: settings.apiKey),
            URLQueryItem(name: "agency", value: operatorId),
            URLQueryItem(name: "stopCode", value: stopCode),
            URLQueryItem(name: "format", value: "json")
        ]

        guard let url = components.url else {
            await MainActor.run {
                errorMessage = "Invalid URL"
                isLoading = false
            }
            return
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw TransitError.invalidResponse
            }

            guard httpResponse.statusCode == 200 else {
                throw TransitError.httpError(httpResponse.statusCode)
            }

            // Remove BOM if present (511 API sometimes includes it)
            let cleanedData: Data
            if data.starts(with: [0xEF, 0xBB, 0xBF]) {
                cleanedData = data.dropFirst(3)
            } else {
                cleanedData = data
            }

            let apiResponse = try JSONDecoder().decode(APIResponse.self, from: cleanedData)
            let departures = parseDepartures(from: apiResponse, lineId: route.lineId)

            await MainActor.run {
                self.departures = departures
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }

    private func parseDepartures(from response: APIResponse, lineId: String) -> [Departure] {
        guard let delivery = response.ServiceDelivery.StopMonitoringDelivery.first,
              let visits = delivery.MonitoredStopVisit else {
            return []
        }

        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let altFormatter = ISO8601DateFormatter()
        altFormatter.formatOptions = [.withInternetDateTime]

        var departures: [Departure] = []

        for visit in visits {
            let journey = visit.MonitoredVehicleJourney

            // Filter by line if specified
            if !lineId.isEmpty {
                guard journey.LineRef == lineId else { continue }
            }

            guard let call = journey.MonitoredCall else { continue }

            let timeString = call.ExpectedDepartureTime ?? call.AimedDepartureTime ??
                            call.ExpectedArrivalTime ?? call.AimedArrivalTime ?? ""

            guard !timeString.isEmpty else { continue }

            var departureTime: Date?
            departureTime = dateFormatter.date(from: timeString)
            if departureTime == nil {
                departureTime = altFormatter.date(from: timeString)
            }

            guard let time = departureTime else { continue }

            // Skip departures in the past
            guard time > Date() else { continue }

            let departure = Departure(
                lineName: journey.PublishedLineName ?? journey.LineRef ?? "Train",
                destination: journey.DestinationName ?? "Unknown",
                departureTime: time,
                isRealTime: journey.Monitored ?? false
            )

            departures.append(departure)
        }

        // Sort by departure time and take first 5
        return Array(departures.sorted { $0.departureTime < $1.departureTime }.prefix(5))
    }
}

enum TransitError: LocalizedError {
    case invalidResponse
    case httpError(Int)
    case noStopsFound

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let code):
            return "Server error: \(code)"
        case .noStopsFound:
            return "No stops found for this operator"
        }
    }
}

// MARK: - Stops API Response

struct StopsResponse: Codable {
    let Contents: StopsContents?
    let Siri: SiriStops?
}

struct StopsContents: Codable {
    let dataObjects: StopsDataObjects?
}

struct StopsDataObjects: Codable {
    let ScheduledStopPoint: [ScheduledStopPoint]?
}

struct ScheduledStopPoint: Codable {
    let id: String?
    let Name: String?
    let Location: StopLocation?
}

struct StopLocation: Codable {
    let Longitude: String?
    let Latitude: String?
}

struct SiriStops: Codable {
    let ServiceDelivery: SiriStopsServiceDelivery?
}

struct SiriStopsServiceDelivery: Codable {
    let DataObjectDelivery: DataObjectDelivery?
}

struct DataObjectDelivery: Codable {
    let dataObjects: SiriDataObjects?
}

struct SiriDataObjects: Codable {
    let SiteFrame: SiteFrame?
}

struct SiteFrame: Codable {
    let stopPlaces: StopPlacesWrapper?
}

struct StopPlacesWrapper: Codable {
    let StopPlace: [StopPlace]?
}

struct StopPlace: Codable {
    let id: String?
    let Name: String?
    let Centroid: Centroid?
}

struct Centroid: Codable {
    let Location: StopLocation?
}

// MARK: - Stops Fetching

extension TransitService {
    func fetchStops(for operatorId: String) async throws -> [Station] {
        guard !settings.apiKey.isEmpty else {
            throw TransitError.invalidResponse
        }

        guard var components = URLComponents(string: "\(baseURL)/stops") else {
            throw TransitError.invalidResponse
        }

        components.queryItems = [
            URLQueryItem(name: "api_key", value: settings.apiKey),
            URLQueryItem(name: "operator_id", value: operatorId),
            URLQueryItem(name: "format", value: "json")
        ]

        guard let url = components.url else {
            throw TransitError.invalidResponse
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TransitError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw TransitError.httpError(httpResponse.statusCode)
        }

        // Remove BOM if present
        let cleanedData: Data
        if data.starts(with: [0xEF, 0xBB, 0xBF]) {
            cleanedData = data.dropFirst(3)
        } else {
            cleanedData = data
        }

        let stopsResponse = try JSONDecoder().decode(StopsResponse.self, from: cleanedData)

        var stations: [Station] = []

        // Try Contents format first (NeTEx)
        if let stops = stopsResponse.Contents?.dataObjects?.ScheduledStopPoint {
            for stop in stops {
                guard let id = stop.id, let name = stop.Name else { continue }
                let lat = stop.Location?.Latitude.flatMap { Double($0) }
                let lon = stop.Location?.Longitude.flatMap { Double($0) }
                stations.append(Station(id: id, name: name, latitude: lat, longitude: lon))
            }
        }

        // Try SIRI/StopPlaces format
        if stations.isEmpty, let stopPlaces = stopsResponse.Siri?.ServiceDelivery?.DataObjectDelivery?.dataObjects?.SiteFrame?.stopPlaces?.StopPlace {
            for place in stopPlaces {
                guard let id = place.id, let name = place.Name else { continue }
                let lat = place.Centroid?.Location?.Latitude.flatMap { Double($0) }
                let lon = place.Centroid?.Location?.Longitude.flatMap { Double($0) }
                stations.append(Station(id: id, name: name, latitude: lat, longitude: lon))
            }
        }

        if stations.isEmpty {
            throw TransitError.noStopsFound
        }

        return stations.sorted { $0.name < $1.name }
    }

    func fetchLines(for operatorId: String) async throws -> [TransitLine] {
        guard !settings.apiKey.isEmpty else {
            throw TransitError.invalidResponse
        }

        guard var components = URLComponents(string: "\(baseURL)/lines") else {
            throw TransitError.invalidResponse
        }

        components.queryItems = [
            URLQueryItem(name: "api_key", value: settings.apiKey),
            URLQueryItem(name: "operator_id", value: operatorId),
            URLQueryItem(name: "format", value: "json")
        ]

        guard let url = components.url else {
            throw TransitError.invalidResponse
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TransitError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw TransitError.httpError(httpResponse.statusCode)
        }

        // Remove BOM if present
        let cleanedData: Data
        if data.starts(with: [0xEF, 0xBB, 0xBF]) {
            cleanedData = data.dropFirst(3)
        } else {
            cleanedData = data
        }

        let linesResponse = try JSONDecoder().decode(LinesResponse.self, from: cleanedData)

        var lines: [TransitLine] = []

        if let linesList = linesResponse.Contents?.dataObjects?.Line ?? linesResponse.Siri?.ServiceDelivery?.DataObjectDelivery?.dataObjects?.ServiceFrame?.lines?.Line {
            for line in linesList {
                guard let id = line.Id ?? line.id else { continue }
                let name = line.Name ?? line.PublicCode ?? ""
                lines.append(TransitLine(id: id, name: name))
            }
        }

        return lines.sorted { $0.displayName < $1.displayName }
    }
}

// MARK: - Lines API Response

struct LinesResponse: Codable {
    let Contents: LinesContents?
    let Siri: SiriLines?
}

struct LinesContents: Codable {
    let dataObjects: LinesDataObjects?
}

struct LinesDataObjects: Codable {
    let Line: [LineData]?
}

struct LineData: Codable {
    let Id: String?
    let id: String?
    let Name: String?
    let PublicCode: String?
}

struct SiriLines: Codable {
    let ServiceDelivery: SiriLinesServiceDelivery?
}

struct SiriLinesServiceDelivery: Codable {
    let DataObjectDelivery: LinesDataObjectDelivery?
}

struct LinesDataObjectDelivery: Codable {
    let dataObjects: SiriLinesDataObjects?
}

struct SiriLinesDataObjects: Codable {
    let ServiceFrame: ServiceFrame?
}

struct ServiceFrame: Codable {
    let lines: LinesWrapper?
}

struct LinesWrapper: Codable {
    let Line: [LineData]?
}
