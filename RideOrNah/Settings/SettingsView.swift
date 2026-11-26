import Entitlements
import RiderSettings
import StoreKit
import SwiftUI

/// Profiles, saved places, units, iCloud sync and the subscription.
struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(AccessController.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var managing = false
    @State private var redeeming = false
    @State private var showsPlans = false

    var body: some View {
        NavigationStack {
            List {
                if let preferences = model.preferences {
                    Section("Profiles") {
                        ForEach(preferences.profiles) { profile in
                            NavigationLink {
                                ProfileEditorView(profile: profile)
                            } label: {
                                HStack {
                                    Text(profile.name)
                                    Spacer()
                                    if profile.id == preferences.activeProfileID {
                                        Text("Active").font(.subheadline).foregroundStyle(Theme.accent)
                                    }
                                }
                            }
                            .accessibilityIdentifier("settings.profile")
                            .swipeActions {
                                if preferences.canDeleteProfiles {
                                    Button("Delete", role: .destructive) {
                                        try? model.update { try $0.deleteProfile(profile.id) }
                                    }
                                }
                            }
                        }
                        Button("Add profile") { model.update { $0.addProfile(named: "New Bike") } }
                            .accessibilityIdentifier("settings.addProfile")
                    }
                    Section("Places") {
                        NavigationLink("Saved places and background location") { LocationsView() }
                            .accessibilityIdentifier("settings.places")
                    }
                    Section {
                        Picker("Units", selection: binding(\.unitPreference)) {
                            Text("Automatic").tag(UnitPreference.automatic)
                            Text("Imperial (mi, °F)").tag(UnitPreference.imperial)
                            Text("Metric (km, °C)").tag(UnitPreference.metric)
                        }
                        .accessibilityIdentifier("settings.units")
                        Toggle("Sync with iCloud", isOn: binding(\.syncEnabled))
                            .tint(Theme.accent)
                    } footer: {
                        Text("Profiles and places sync through your own iCloud. Nothing goes to us.")
                    }
                    Section {
                        LabeledContent("Plan", value: Self.planText(store.access))
                            .accessibilityIdentifier("settings.plan")
                        if store.access.isActive {
                            Button("Manage subscription") { managing = true }
                        } else {
                            Button("See plans") { showsPlans = true }
                                .accessibilityIdentifier("settings.seePlans")
                        }
                        Button("Restore Purchases") { Task { await store.restore() } }
                        Button("Redeem code") { redeeming = true }
                    } header: {
                        Text("Subscription")
                    } footer: {
                        if let message = store.message { Text(message) }
                    }
                    #if DEBUG
                        Section("Developer") {
                            NavigationLink("Weather pipeline") { WeatherDebugView() }
                                .accessibilityIdentifier("settings.weatherDebug")
                        }
                    #endif
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.ground)
            .navigationTitle("Settings")
            .toolbar { Button("Done") { dismiss() } }
            .manageSubscriptionsSheet(isPresented: $managing)
            .offerCodeRedemption(isPresented: $redeeming) { _ in Task { await store.refresh() } }
            .fullScreenCover(isPresented: $showsPlans) { PaywallView { showsPlans = false } }
            .onChange(of: store.access.isActive) { _, active in if active { showsPlans = false } }
        }
        .accessibilityIdentifier("settings.screen")
    }

    static func planText(_ access: Access) -> String {
        switch access {
        case .inactive: "Not subscribed"
        case .active(let plan, let inTrial, let renews):
            [plan == .annual ? "Annual" : "Monthly", inTrial ? "free trial" : nil, renews ? nil : "not renewing"]
                .compactMap { $0 }.joined(separator: ", ")
        }
    }

    func binding<Value>(_ keyPath: WritableKeyPath<Preferences, Value>) -> Binding<Value> {
        Binding(
            get: { model.preferences![keyPath: keyPath] },
            set: { value in
                model.update {
                    $0[keyPath: keyPath] = value
                    $0.sharedModifiedAt = Date()
                }
            })
    }
}
