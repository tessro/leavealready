import SwiftUI

struct AddRouteView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    let editingRoute: ConfiguredRoute?

    @State private var routeName = ""
    @State private var selectedOperator = BayAreaOperator.bart
    @State private var selectedLine: TransitLine?
    @State private var originStation: Station?
    @State private var originSearchText = ""
    @State private var availableStops: [Station] = []
    @State private var availableLines: [TransitLine] = []
    @State private var isLoadingStops = false
    @State private var isLoadingLines = false
    @State private var stopsError: String?
    @State private var linesError: String?
    @FocusState private var isOriginFocused: Bool

    private let transitService = TransitService()

    init(editingRoute: ConfiguredRoute? = nil) {
        self.editingRoute = editingRoute
    }

    private var filteredStops: [Station] {
        if originSearchText.isEmpty {
            return availableStops
        }
        return availableStops.filter { $0.name.localizedCaseInsensitiveContains(originSearchText) }
    }

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
                .onChange(of: selectedOperator) { _, _ in
                    loadStops()
                    loadLines()
                }
            } header: {
                Text("Route Info")
            }

            Section {
                if isLoadingLines {
                    HStack {
                        ProgressView()
                        Text("Loading lines...")
                            .foregroundStyle(.secondary)
                    }
                } else if let error = linesError {
                    Text(error)
                        .foregroundStyle(.red)
                    Button("Retry") {
                        loadLines()
                    }
                } else if availableLines.isEmpty {
                    Text("No lines available")
                        .foregroundStyle(.secondary)
                } else {
                    Picker("Line", selection: $selectedLine) {
                        Text("All lines").tag(nil as TransitLine?)
                        ForEach(availableLines) { line in
                            Text(line.displayName).tag(line as TransitLine?)
                        }
                    }
                }
            } header: {
                Text("Line (optional)")
            } footer: {
                Text("Filter departures to a specific line")
            }

            Section {
                if isLoadingStops {
                    HStack {
                        ProgressView()
                        Text("Loading stations...")
                            .foregroundStyle(.secondary)
                    }
                } else if let error = stopsError {
                    Text(error)
                        .foregroundStyle(.red)
                    Button("Retry") {
                        loadStops()
                    }
                } else if availableStops.isEmpty {
                    Text("No stations available")
                        .foregroundStyle(.secondary)
                } else {
                    TextField("Search stations...", text: $originSearchText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($isOriginFocused)

                    if let station = originStation, !isOriginFocused {
                        HStack {
                            Text(station.name)
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }
                    } else {
                        ForEach(filteredStops.prefix(8)) { stop in
                            Button(action: {
                                originStation = stop
                                originSearchText = stop.name
                                isOriginFocused = false
                            }) {
                                HStack {
                                    Text(stop.name)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    if originStation?.id == stop.id {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.blue)
                                    }
                                }
                            }
                        }
                    }
                }
            } header: {
                Text("Origin Station")
            }

            Section {
                Button(action: saveRoute) {
                    HStack {
                        Spacer()
                        Text(editingRoute != nil ? "Update Route" : "Save Route")
                            .font(.headline)
                        Spacer()
                    }
                }
                .disabled(!isValid)
            }
        }
        .navigationTitle(editingRoute != nil ? "Edit Route" : "Add Route")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if let route = editingRoute {
                routeName = route.name
                if let op = BayAreaOperator(rawValue: route.operatorId) {
                    selectedOperator = op
                }
                originStation = route.originStation
                originSearchText = route.originStation.name
            }
            loadStops()
            loadLines()
        }
    }

    private var isValid: Bool {
        !routeName.isEmpty && originStation != nil
    }

    private func loadStops() {
        isLoadingStops = true
        stopsError = nil
        originStation = nil
        originSearchText = ""
        availableStops = []

        Task {
            do {
                let stops = try await transitService.fetchStops(for: selectedOperator.rawValue)
                await MainActor.run {
                    availableStops = stops
                    isLoadingStops = false
                }
            } catch {
                await MainActor.run {
                    stopsError = error.localizedDescription
                    isLoadingStops = false
                }
            }
        }
    }

    private func loadLines() {
        isLoadingLines = true
        linesError = nil
        selectedLine = nil
        availableLines = []

        Task {
            do {
                let lines = try await transitService.fetchLines(for: selectedOperator.rawValue)
                await MainActor.run {
                    availableLines = lines
                    isLoadingLines = false
                    // Pre-select line when editing
                    if let route = editingRoute, !route.lineId.isEmpty {
                        selectedLine = lines.first { $0.id == route.lineId }
                    }
                }
            } catch {
                await MainActor.run {
                    linesError = error.localizedDescription
                    isLoadingLines = false
                }
            }
        }
    }

    private func saveRoute() {
        guard let origin = originStation else { return }

        let route = ConfiguredRoute(
            id: editingRoute?.id ?? UUID(),
            name: routeName,
            operatorId: selectedOperator.rawValue,
            lineId: selectedLine?.id ?? "",
            originStation: origin
        )

        if editingRoute != nil {
            appState.settings.updateRoute(route)
        } else {
            appState.settings.addRoute(route)
        }
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
