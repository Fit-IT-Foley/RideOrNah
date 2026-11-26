import RiderSettings
import SwiftUI
import VerdictEngine

/// First-run setup: riding style, the main limits, then location. Progress is saved after
/// every step, so quitting resumes at the same step.
struct FirstRunView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Wordmark()
                    if let flow = model.firstRun {
                        switch flow.step {
                        case .style: StyleStep()
                        case .limits: LimitsStep(limits: flow.draft.limits)
                        case .locationExplanation: LocationStep()
                        case .addSavedLocation: SavedPlaceStep()
                        case .done: EmptyView()
                        }
                    }
                }
                .padding(20)
            }
            .background(Theme.ground)
        }
        .accessibilityIdentifier("firstRun.screen")
    }
}

private struct StepHeader: View {
    let title: String
    let detail: String
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(Theme.display(.largeTitle))
                .foregroundStyle(Theme.ink)
                .accessibilityAddTraits(.isHeader)
            Text(detail).font(.body).foregroundStyle(Theme.inkSecondary)
        }
    }
}

private struct StyleStep: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            StepHeader(
                title: "How do you ride?",
                detail: "Ride or Nah only judges the hours you actually ride. You can change these any time.")
            option(.commute, "Commute", "Weekdays, 7–9 AM and 4–6 PM")
            option(.weekends, "Weekends", "Saturday and Sunday, 9 AM–5 PM")
            option(.anytime, "Anytime", "Every day, sunrise to sunset")
        }
    }

    func option(_ style: RidingStyle, _ title: String, _ detail: String) -> some View {
        Button {
            model.updateFirstRun { $0.choose(style) }
        } label: {
            Card {
                Text(title).font(Theme.display(.title2)).foregroundStyle(Theme.ink)
                Text(detail).font(.subheadline).foregroundStyle(Theme.inkSecondary)
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("firstRun.style.\(style.rawValue)")
    }
}

private struct LimitsStep: View {
    @Environment(AppModel.self) private var model
    @State var limits: Limits
    @State private var units = UnitPreference.automatic.resolved()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            StepHeader(
                title: "Your limits",
                detail: "Soft limits make it a Maybe; hard limits make it a Nah. These defaults suit most riders.")
            Card {
                LimitRow(title: "Rain chance", quantity: .percentage, limit: $limits.precipitation.chance, units: units)
                LimitRow(title: "Cold", quantity: .temperature, limit: $limits.cold, units: units)
                LimitRow(title: "Heat (feels like)", quantity: .temperature, limit: $limits.heat, units: units)
                LimitRow(title: "Wind", quantity: .speed, limit: $limits.wind, units: units)
                LimitRow(title: "Gusts", quantity: .speed, limit: $limits.gusts, units: units)
            }
            Button("Use these limits") { model.updateFirstRun { $0.confirmLimits(limits) } }
                .buttonStyle(PrimaryButtonStyle())
                .accessibilityIdentifier("firstRun.limits.confirm")
        }
    }
}

private struct LocationStep: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            StepHeader(
                title: "Where you ride",
                detail:
                    "Your location is used only to fetch weather. It's rounded to about a kilometre and sent only to Apple: to Apple Weather for forecasts, and, for places you save, to your own iCloud."
            )
            Button("Use my location") {
                Task {
                    let granted = await model.location.requestPermission()
                    model.updateFirstRun { $0.locationPermission(granted: granted) }
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .accessibilityIdentifier("firstRun.location.allow")
            Button("Add a place instead") { model.updateFirstRun { $0.locationPermission(granted: false) } }
                .buttonStyle(SecondaryButtonStyle())
                .accessibilityIdentifier("firstRun.location.instead")
        }
    }
}

private struct SavedPlaceStep: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            StepHeader(
                title: "Add a place",
                detail: "Without your location, Ride or Nah checks the weather at a place you save, such as Home.")
            PlaceSearchView { result in
                model.updateFirstRun { $0.addSavedLocation(named: "Home", at: result.coordinate) }
            }
        }
    }
}
