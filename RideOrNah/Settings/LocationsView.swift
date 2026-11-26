import MapKit
import RiderSettings
import SwiftUI
import WeatherData

/// Saved places (at most 10) and where notifications and widgets check the weather.
struct LocationsView: View {
    @Environment(AppModel.self) private var model
    @State private var adding = false
    @State private var dropping = false

    var body: some View {
        List {
            if let preferences = model.preferences {
                Section {
                    ForEach(preferences.savedLocations) { place in
                        Text(place.name).accessibilityIdentifier("places.saved")
                    }
                    .onDelete { offsets in
                        let ids = offsets.map { preferences.savedLocations[$0].id }
                        model.update { prefs in
                            for id in ids { prefs.deleteSavedLocation(id) }
                        }
                    }
                    if preferences.canAddSavedLocation {
                        Button("Add by search") { adding = true }.accessibilityIdentifier("places.add")
                        Button("Add my current location") { Task { await addCurrent() } }
                        Button("Drop a pin on the map") { dropping = true }
                    } else {
                        Text("You've saved 10 places. Delete one to add another.").foregroundStyle(Theme.inkTertiary)
                    }
                } header: {
                    Text("Saved places")
                }
                Section {
                    Picker("Check the weather at", selection: backgroundBinding) {
                        ForEach(preferences.savedLocations) { Text($0.name).tag(BackgroundSource.saved($0.id)) }
                        Text("Where I last opened the app").tag(BackgroundSource.lastSeen)
                    }
                    .pickerStyle(.inline)
                } header: {
                    Text("For notifications and widgets")
                } footer: {
                    Text("Where you last opened the app is kept on this iPhone only.")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.ground)
        .navigationTitle("Places")
        .sheet(isPresented: $adding) {
            NavigationStack {
                ScrollView {
                    PlaceSearchView { result in
                        try? model.update { try $0.addSavedLocation(named: result.name, at: result.coordinate) }
                        adding = false
                    }
                    .padding(20)
                }
                .background(Theme.ground)
                .navigationTitle("Add a place")
            }
        }
        .sheet(isPresented: $dropping) { PinDropView() }
    }

    var backgroundBinding: Binding<BackgroundSource> {
        Binding(
            get: { model.preferences?.effectiveBackgroundSource ?? .lastSeen },
            set: { source in
                model.update {
                    $0.backgroundSource = source
                    $0.sharedModifiedAt = Date()
                }
            })
    }

    func addCurrent() async {
        guard await model.location.requestPermission(), let reading = await model.location.currentReading() else {
            return
        }
        try? model.update { try $0.addSavedLocation(named: "Current location", at: reading.coordinate) }
    }
}

/// Tap the map to place a pin, name it, and save it.
struct PinDropView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var pin: CLLocationCoordinate2D?
    @State private var name = "Pinned place"

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                MapReader { proxy in
                    Map {
                        if let pin { Marker(name, coordinate: pin).tint(Theme.accent) }
                    }
                    .onTapGesture { point in pin = proxy.convert(point, from: .local) }
                }
                TextField("Name", text: $name).textFieldStyle(.roundedBorder).padding(.horizontal)
                Button("Save place") {
                    guard let pin else { return }
                    try? model.update {
                        try $0.addSavedLocation(
                            named: name, at: GeoCoordinate(latitude: pin.latitude, longitude: pin.longitude))
                    }
                    dismiss()
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(pin == nil)
                .padding()
            }
            .background(Theme.ground)
            .navigationTitle("Drop a pin")
            .toolbar { Button("Cancel") { dismiss() } }
        }
    }
}
