import SwiftUI

/// Placeholder until `today-and-outlook` replaces it with the Today screen.
struct RootView: View {
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
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(24)
            .adaptiveSurface(in: .rect(cornerRadius: 28))
            .padding()
        }
        .background(Color(.systemGroupedBackground))
    }
}

#Preview {
    RootView()
}
