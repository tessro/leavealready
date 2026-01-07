import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Group {
            if !appState.settings.hasValidConfiguration {
                SetupPromptView()
            } else {
                DepartureView()
            }
        }
        .sheet(isPresented: $appState.showSettings) {
            SettingsView()
        }
        .onAppear {
            appState.locationManager.requestPermission()
        }
    }
}

struct SetupPromptView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "tram.fill")
                .font(.system(size: 80))
                .foregroundColor(.blue)

            Text("Leave")
                .font(.system(size: 48, weight: .bold, design: .rounded))

            Text("Set up your commute")
                .font(.title2)
                .foregroundColor(.secondary)

            Spacer()

            Button(action: {
                appState.showSettings = true
            }) {
                Text("Get Started")
                    .font(.title2.bold())
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .background(Color.blue)
                    .cornerRadius(16)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
        .background(Color(.systemBackground))
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}
