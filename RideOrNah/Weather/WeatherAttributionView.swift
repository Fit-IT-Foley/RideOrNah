import SwiftUI
import WeatherData

/// The Apple Weather mark for the current appearance and a link to Apple's attribution page.
/// Every screen that shows weather-derived information includes it; the link opens in Safari.
struct WeatherAttributionView: View {
    let info: WeatherAttributionInfo
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            mark
                .accessibilityIdentifier("attribution.mark")
            Link("Weather data sources", destination: info.legalPageURL)
                .font(.footnote)
                .accessibilityIdentifier("attribution.link")
        }
    }

    @ViewBuilder private var mark: some View {
        if let url = colorScheme == .dark ? info.darkMarkURL : info.lightMarkURL {
            AsyncImage(url: url) { image in
                image.resizable().scaledToFit()
            } placeholder: {
                Text("Apple Weather").font(.footnote)
            }
            .frame(height: 12)
            .accessibilityLabel("Apple Weather")
        } else {
            // Fixture builds can't ask WeatherKit for the mark.
            Label("Apple Weather", systemImage: "cloud.sun")
                .font(.footnote)
        }
    }
}

#Preview {
    WeatherAttributionView(info: .fixture).padding()
}
