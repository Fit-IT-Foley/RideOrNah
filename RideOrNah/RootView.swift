import SwiftUI

/// Placeholder until `today-and-outlook` replaces it with the Today screen. Shows first-run setup
/// until it's done, and opens settings from the gear.
struct RootView: View {
    @Environment(AppModel.self) private var model
    @State private var showsSettings = false
    #if DEBUG
        @State private var showsWeatherDebug = UserDefaults.standard.bool(forKey: "openWeatherDebug")
    #endif

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Wordmark()
                    Spacer()
                    Button {
                        showsSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.title3)
                            .frame(width: 44, height: 44)
                            .foregroundStyle(Theme.ink)
                            .adaptiveSurface(in: .circle)
                    }
                    .accessibilityLabel("Settings")
                    .accessibilityIdentifier("root.settings")
                }
                VStack(spacing: 12) {
                    Text("RideOrNah")
                        .font(Theme.display(.largeTitle))
                        .foregroundStyle(Theme.ink)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityIdentifier("root.title")
                    Text("Your daily ride check is on its way.")
                        .font(.body)
                        .foregroundStyle(Theme.inkSecondary)
                        .accessibilityIdentifier("root.subtitle")
                    if let profile = model.preferences?.activeProfile {
                        Text("Riding with \(profile.name)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.accent)
                            .accessibilityIdentifier("root.profile")
                    }
                    #if DEBUG
                        Button("Weather pipeline (debug)") { showsWeatherDebug = true }
                            .accessibilityIdentifier("root.weatherDebug")
                    #endif
                }
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(24)
                .adaptiveSurface(in: .rect(cornerRadius: 28))
            }
            .padding()
        }
        .background(Theme.ground)
        .sheet(isPresented: $showsSettings) { SettingsView() }
        .fullScreenCover(isPresented: .constant(model.needsFirstRun)) { FirstRunView() }
        #if DEBUG
            .sheet(isPresented: $showsWeatherDebug) { WeatherDebugView() }
        #endif
    }
}

#if DEBUG
    #Preview {
        RootView().environment(AppModel.preview())
    }
#endif
