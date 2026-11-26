import SwiftUI
import WeatherData

/// Search for a place by address or name. Search text goes to Apple Maps.
struct PlaceSearchView: View {
    @Environment(AppModel.self) private var model
    @State private var query = ""
    @State private var results: [PlaceResult] = []
    @State private var searched = false
    let onPick: (PlaceResult) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(Theme.inkQuiet)
                TextField("Address or place", text: $query)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.search)
                    .onSubmit(search)
                    .accessibilityIdentifier("places.search")
            }
            .padding(12)
            .background(Theme.card, in: .rect(cornerRadius: 14))
            ForEach(results) { result in
                Button {
                    onPick(result)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(result.name).font(.headline).foregroundStyle(Theme.ink)
                        if !result.subtitle.isEmpty {
                            Text(result.subtitle).font(.subheadline).foregroundStyle(Theme.inkTertiary)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("places.result")
            }
            if searched && results.isEmpty {
                Text("No places found.").foregroundStyle(Theme.inkTertiary)
            }
        }
    }

    func search() {
        let text = query.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        Task {
            results = await model.placeSearch.search(text)
            searched = true
        }
    }
}
