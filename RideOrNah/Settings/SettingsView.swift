import RiderSettings
import SwiftUI

/// Profiles, saved places, units and iCloud sync.
struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

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
        }
        .accessibilityIdentifier("settings.screen")
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
