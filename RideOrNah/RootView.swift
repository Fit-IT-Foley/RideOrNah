import SwiftUI

/// Placeholder until `today-and-outlook` replaces it with the Today screen.
struct RootView: View {
    #if DEBUG
        @State private var showsWeatherDebug = UserDefaults.standard.bool(forKey: "openWeatherDebug")
    #endif

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Text("RideOrNah")
                    .font(.largeTitle.bold())
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("root.title")
                Text("Your daily ride check is on its way.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("root.subtitle")
                #if DEBUG
                    Button("Weather pipeline (debug)") { showsWeatherDebug = true }
                        .accessibilityIdentifier("root.weatherDebug")
                #endif
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(24)
            .adaptiveSurface(in: .rect(cornerRadius: 28))
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        #if DEBUG
            .sheet(isPresented: $showsWeatherDebug) { WeatherDebugView() }
        #endif
    }
}

#Preview {
    RootView()
}
