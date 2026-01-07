import SwiftUI

struct DepartureView: View {
    @EnvironmentObject var appState: AppState
    @State private var refreshTimer: Timer?

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    if let route = appState.activeRoute {
                        routeHeader(route)
                        departuresList
                    } else {
                        noRouteView
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { appState.showSettings = true }) {
                        Image(systemName: "gear")
                            .font(.title2)
                    }
                }
            }
            .onAppear {
                startRefreshing()
            }
            .onDisappear {
                stopRefreshing()
            }
            .refreshable {
                appState.refresh()
            }
        }
    }

    private func routeHeader(_ route: ConfiguredRoute) -> some View {
        VStack(spacing: 8) {
            Text(route.originStation.name)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.7)
                .lineLimit(1)

            if !route.lineId.isEmpty {
                Text(route.lineId)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
    }

    private var departuresList: some View {
        Group {
            if appState.transitService.isLoading && appState.transitService.departures.isEmpty {
                loadingView
            } else if let error = appState.transitService.errorMessage {
                errorView(error)
            } else if appState.transitService.departures.isEmpty {
                emptyView
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(appState.transitService.departures) { departure in
                            DepartureRow(departure: departure)
                        }
                    }
                    .padding()
                }
            }
        }
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading...")
                .font(.title3)
                .foregroundColor(.secondary)
            Spacer()
        }
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            Text(message)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button("Retry") {
                appState.fetchDepartures()
            }
            .font(.headline)
            Spacer()
        }
    }

    private var emptyView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "tram")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("No upcoming departures")
                .font(.title3)
                .foregroundColor(.secondary)
            Spacer()
        }
    }

    private var noRouteView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "location.slash.fill")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("Finding nearest station...")
                .font(.title3)
                .foregroundColor(.secondary)
            Button("Refresh Location") {
                appState.locationManager.requestLocation()
            }
            .font(.headline)
            Spacer()
        }
    }

    private func startRefreshing() {
        appState.refresh()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
            appState.fetchDepartures()
        }
    }

    private func stopRefreshing() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
}

struct DepartureRow: View {
    let departure: Departure

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text(departure.lineName)
                    .font(.system(size: 20, weight: .semibold, design: .rounded))

                Text(departure.destination)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(departure.timeString)
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(departure.minutesUntilDeparture <= 5 ? .orange : .primary)

                if departure.isRealTime {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                        Text("Live")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
    }
}

#Preview {
    DepartureView()
        .environmentObject(AppState())
}
