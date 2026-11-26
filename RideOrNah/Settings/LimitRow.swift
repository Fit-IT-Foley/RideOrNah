import RiderSettings
import SwiftUI
import VerdictEngine

/// One factor's soft and hard limits, edited in the rider's units and stored in SI.
struct LimitRow: View {
    let title: String
    let quantity: Quantity
    @Binding var limit: ThresholdLimit
    let units: UnitSystem
    var showsToggle = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title).font(.headline).foregroundStyle(Theme.ink)
                Spacer()
                if showsToggle {
                    Toggle("", isOn: $limit.isEnabled).labelsHidden().tint(Theme.accent)
                        .accessibilityLabel("\(title) on")
                }
            }
            if limit.isEnabled {
                HStack(spacing: 12) {
                    field("Soft", value: $limit.soft)
                    field("Hard", value: $limit.hard)
                }
            }
        }
    }

    func field(_ label: String, value: Binding<Double?>) -> some View {
        let display = Binding<Double?>(
            get: { value.wrappedValue.map { (quantity.display($0, in: units) * 10).rounded() / 10 } },
            set: { value.wrappedValue = $0.map { quantity.si(fromDisplay: $0, in: units) } })
        return VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased()).font(.caption2.weight(.bold)).tracking(0.5).foregroundStyle(Theme.inkTertiary)
            HStack(spacing: 4) {
                TextField("None", value: display, format: .number)
                    .keyboardType(.decimalPad)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                    .accessibilityLabel("\(title) \(label.lowercased()) limit")
                    .accessibilityIdentifier("limit.\(title).\(label.lowercased())")
                Text(quantity.symbol(in: units)).foregroundStyle(Theme.inkTertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
