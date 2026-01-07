import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            List {
                apiKeySection
                routesSection
                infoSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.headline)
                }
            }
        }
    }

    private var apiKeySection: some View {
        Section {
            SecureInputField(
                title: "API Key",
                text: Binding(
                    get: { appState.settings.apiKey },
                    set: { appState.settings.apiKey = $0 }
                )
            )
        } header: {
            Text("511.org API")
        } footer: {
            Text("Get your free API key at 511.org/open-data")
        }
    }

    private var routesSection: some View {
        Section {
            ForEach(appState.settings.routes) { route in
                RouteRow(route: route)
            }
            .onDelete { indexSet in
                appState.settings.removeRoute(at: indexSet)
            }

            NavigationLink {
                AddRouteView()
            } label: {
                Label("Add Route", systemImage: "plus.circle.fill")
                    .foregroundColor(.blue)
            }
        } header: {
            Text("Routes")
        } footer: {
            Text("Add your home↔work route. The app will automatically show departures from the nearest station.")
        }
    }

    private var infoSection: some View {
        Section {
            HStack {
                Text("Location Status")
                Spacer()
                Text(locationStatusText)
                    .foregroundColor(.secondary)
            }
        } header: {
            Text("Status")
        }
    }

    private var locationStatusText: String {
        switch appState.locationManager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            return "Enabled"
        case .denied, .restricted:
            return "Denied"
        case .notDetermined:
            return "Not Set"
        @unknown default:
            return "Unknown"
        }
    }
}

struct SecureInputField: View {
    let title: String
    @Binding var text: String
    @State private var isRevealed = false

    var body: some View {
        HStack {
            if isRevealed {
                TextField(title, text: $text)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            } else {
                SecureField(title, text: $text)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }

            Button(action: { isRevealed.toggle() }) {
                Image(systemName: isRevealed ? "eye.slash" : "eye")
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct RouteRow: View {
    let route: ConfiguredRoute

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(route.name)
                .font(.headline)

            Text("\(route.originStation.name) ↔ \(route.destinationStation.name)")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppState())
}
