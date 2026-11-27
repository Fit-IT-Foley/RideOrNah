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
    /// What the switch turns on and off when it's more than this limit, such as all of rain.
    var isOn: Binding<Bool>?

    var body: some View {
        let enabled = isOn ?? $limit.isEnabled
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title).font(.headline).foregroundStyle(Theme.ink)
                Spacer()
                if showsToggle {
                    Toggle("", isOn: enabled).labelsHidden().tint(Theme.accent)
                        .accessibilityLabel("\(title) on")
                }
            }
            if enabled.wrappedValue {
                HStack(spacing: 12) {
                    field("Soft", value: $limit.soft)
                    field("Hard", value: $limit.hard)
                }
            }
        }
    }

    func field(_ label: String, value: Binding<Double?>) -> some View {
        let display = Binding<Double?>(
            get: { value.wrappedValue.map { quantity.roundedDisplay($0, in: units) } },
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
