import SwiftUI

struct AddRouteView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    @State private var routeName = ""
    @State private var selectedOperator = BayAreaOperator.bart
    @State private var lineId = ""
    @State private var originStopCode = ""
    @State private var originName = ""
    @State private var originLat = ""
    @State private var originLon = ""
    @State private var destStopCode = ""
    @State private var destName = ""
    @State private var destLat = ""
    @State private var destLon = ""

    var body: some View {
        Form {
            Section {
                TextField("Route Name", text: $routeName)
                    .textInputAutocapitalization(.words)

                Picker("Transit Agency", selection: $selectedOperator) {
                    ForEach(BayAreaOperator.allCases, id: \.self) { op in
                        Text(op.displayName).tag(op)
                    }
                }

                TextField("Line ID (optional)", text: $lineId)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            } header: {
                Text("Route Info")
            } footer: {
                Text("Line ID filters departures (e.g., 'BLUE' for BART Blue line)")
            }

            Section {
                TextField("Stop Code", text: $originStopCode)
                    .keyboardType(.asciiCapable)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                TextField("Station Name", text: $originName)

                HStack {
                    TextField("Latitude", text: $originLat)
                        .keyboardType(.decimalPad)
                    TextField("Longitude", text: $originLon)
                        .keyboardType(.numbersAndPunctuation)
                }
            } header: {
                Text("Origin Station (e.g., Home)")
            } footer: {
                Text("Find stop codes at 511.org/open-data/transit")
            }

            Section {
                TextField("Stop Code", text: $destStopCode)
                    .keyboardType(.asciiCapable)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                TextField("Station Name", text: $destName)

                HStack {
                    TextField("Latitude", text: $destLat)
                        .keyboardType(.decimalPad)
                    TextField("Longitude", text: $destLon)
                        .keyboardType(.numbersAndPunctuation)
                }
            } header: {
                Text("Destination Station (e.g., Work)")
            }

            Section {
                Button(action: saveRoute) {
                    HStack {
                        Spacer()
                        Text("Save Route")
                            .font(.headline)
                        Spacer()
                    }
                }
                .disabled(!isValid)
            }
        }
        .navigationTitle("Add Route")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var isValid: Bool {
        !routeName.isEmpty &&
        !originStopCode.isEmpty &&
        !originName.isEmpty &&
        Double(originLat) != nil &&
        Double(originLon) != nil &&
        !destStopCode.isEmpty &&
        !destName.isEmpty &&
        Double(destLat) != nil &&
        Double(destLon) != nil
    }

    private func saveRoute() {
        guard let oLat = Double(originLat),
              let oLon = Double(originLon),
              let dLat = Double(destLat),
              let dLon = Double(destLon) else { return }

        let origin = Station(
            id: originStopCode,
            name: originName,
            latitude: oLat,
            longitude: oLon
        )

        let destination = Station(
            id: destStopCode,
            name: destName,
            latitude: dLat,
            longitude: dLon
        )

        let route = ConfiguredRoute(
            name: routeName,
            operatorId: selectedOperator.rawValue,
            lineId: lineId,
            originStation: origin,
            destinationStation: destination
        )

        appState.settings.addRoute(route)
        dismiss()
    }
}

enum BayAreaOperator: String, CaseIterable {
    case bart = "BA"
    case caltrain = "CT"
    case muni = "SF"
    case vta = "SC"
    case actransit = "AC"
    case samtrans = "SM"
    case goldenGate = "GG"

    var displayName: String {
        switch self {
        case .bart: return "BART"
        case .caltrain: return "Caltrain"
        case .muni: return "SF Muni"
        case .vta: return "VTA"
        case .actransit: return "AC Transit"
        case .samtrans: return "SamTrans"
        case .goldenGate: return "Golden Gate Transit"
        }
    }
}

#Preview {
    NavigationStack {
        AddRouteView()
            .environmentObject(AppState())
    }
}
