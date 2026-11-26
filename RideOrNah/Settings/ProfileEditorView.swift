import RiderSettings
import SwiftUI
import VerdictEngine

/// Edits one profile: name, limits for every factor, ride windows, default radius and durations.
/// Saving is disabled while anything is invalid, and the problems are listed.
struct ProfileEditorView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State var profile: RiderProfile

    var units: UnitSystem { model.preferences?.unitPreference.resolved() ?? .imperial }
    var problems: [ValidationError] {
        LimitValidator.problems(in: profile) + WindowValidator.problems(in: profile.windows)
    }
    var isActive: Bool { model.preferences?.activeProfileID == profile.id }

    var body: some View {
        Form {
            Section {
                TextField("Name", text: $profile.name).accessibilityIdentifier("profile.name")
                if !isActive {
                    Button("Ride with this profile") { try? model.update { try $0.activate(profile.id) } }
                }
            }
            if !problems.isEmpty {
                Section {
                    ForEach(problems, id: \.message) { problem in
                        Label(problem.message, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(Theme.reasonWarm)
                            .accessibilityIdentifier("profile.problem")
                    }
                }
            }
            Section("Limits") {
                Toggle("Rain", isOn: $profile.limits.precipitation.isEnabled).tint(Theme.accent)
                if profile.limits.precipitation.isEnabled {
                    LimitRow(
                        title: "Rain chance", quantity: .percentage, limit: $profile.limits.precipitation.chance,
                        units: units)
                    LimitRow(
                        title: "Rain intensity", quantity: .precipitationRate,
                        limit: $profile.limits.precipitation.intensity, units: units)
                }
                LimitRow(
                    title: "Cold", quantity: .temperature, limit: $profile.limits.cold, units: units, showsToggle: true)
                LimitRow(
                    title: "Heat (feels like)", quantity: .temperature, limit: $profile.limits.heat, units: units,
                    showsToggle: true)
                LimitRow(
                    title: "Humidity", quantity: .percentage, limit: $profile.limits.humidity, units: units,
                    showsToggle: true)
                LimitRow(title: "Wind", quantity: .speed, limit: $profile.limits.wind, units: units, showsToggle: true)
                LimitRow(
                    title: "Gusts", quantity: .speed, limit: $profile.limits.gusts, units: units, showsToggle: true)
                LimitRow(
                    title: "UV index", quantity: .index, limit: $profile.limits.uv, units: units, showsToggle: true)
                LimitRow(
                    title: "Visibility", quantity: .distance, limit: $profile.limits.visibility, units: units,
                    showsToggle: true)
                Toggle("Wet roads after rain", isOn: $profile.limits.wetRoads.isEnabled).tint(Theme.accent)
                if profile.limits.wetRoads.isEnabled {
                    Stepper(
                        "For \(Int(profile.limits.wetRoads.duration / 3600)) h after rain",
                        value: $profile.limits.wetRoads.duration, in: 0...(12 * 3600), step: 3600)
                    Picker("Counts as", selection: $profile.limits.wetRoads.severity) {
                        Text("Maybe").tag(Severity.soft)
                        Text("Nah").tag(Severity.hard)
                    }
                }
                Toggle("Ice risk (always a Nah)", isOn: $profile.limits.ice.isEnabled).tint(Theme.accent)
                Toggle("Severe weather alerts", isOn: $profile.limits.alertsEnabled).tint(Theme.accent)
                Button("Reset limits to defaults") { profile.resetLimits() }
            }
            Section("Ride windows") {
                ForEach(profile.windows.indices, id: \.self) { index in
                    WindowEditor(window: $profile.windows[index])
                }
                .onDelete { profile.windows.remove(atOffsets: $0) }
                Button("Add window") {
                    profile.windows.append(RideWindow(weekdays: [2, 3, 4, 5, 6], from: (12, 0), to: (13, 0)))
                }
            }
            Section("Riding") {
                Picker("Default radius", selection: $profile.radius) {
                    ForEach(RadiusPreset.allCases, id: \.self) { Text($0.label(in: units)).tag($0) }
                }
                Stepper(
                    "Suggest rides of \(String(format: "%.1f", profile.minimumRideDuration / 3600)) h or more",
                    value: $profile.minimumRideDuration, in: (30 * 60)...(8 * 3600), step: 30 * 60)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.ground)
        .navigationTitle(profile.name)
        .toolbar {
            Button("Save") {
                model.update { $0.update(profile) }
                dismiss()
            }
            .disabled(!problems.isEmpty)
            .accessibilityIdentifier("profile.save")
        }
    }
}

/// Weekdays and start and end times for one ride window.
struct WindowEditor: View {
    @Binding var window: RideWindow
    static let days = [(2, "M"), (3, "T"), (4, "W"), (5, "T"), (6, "F"), (7, "S"), (1, "S")]
    static let names = [
        1: "Sunday", 2: "Monday", 3: "Tuesday", 4: "Wednesday", 5: "Thursday", 6: "Friday", 7: "Saturday",
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                ForEach(Self.days, id: \.0) { day, letter in
                    let on = window.weekdays.contains(day)
                    Button(letter) {
                        if on { window.weekdays.remove(day) } else { window.weekdays.insert(day) }
                    }
                    .buttonStyle(.plain)
                    .frame(width: 34, height: 34)
                    .foregroundStyle(on ? Theme.ground : Theme.ink)
                    .background(on ? Theme.accent : Theme.card, in: .circle)
                    .accessibilityLabel(Self.names[day] ?? "")
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
            }
            HStack {
                DatePicker("From", selection: minutes(\.start), displayedComponents: .hourAndMinute)
                DatePicker("To", selection: minutes(\.end), displayedComponents: .hourAndMinute)
            }
            .labelsHidden()
        }
    }

    func minutes(_ keyPath: WritableKeyPath<RideWindow, Int>) -> Binding<Date> {
        let midnight = Calendar.current.startOfDay(for: Date())
        return Binding(
            get: { midnight.addingTimeInterval(Double(window[keyPath: keyPath]) * 60) },
            set: { date in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
                window[keyPath: keyPath] = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
            })
    }
}
