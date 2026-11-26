import Presentation
import RiderSettings
import SwiftUI
import UIKit

/// Notification settings, as the design's "Notification settings" board draws it.
struct AlertsView: View {
    @Environment(AppModel.self) private var model
    @Environment(NotificationCoordinator.self) private var notifications
    @Environment(ForecastController.self) private var forecast

    /// What to tell the rider when notifications are off in iOS Settings.
    static func permissionNote(for authorization: NotificationAuthorization) -> String? {
        authorization == .denied
            ? "Notifications are off for Ride or Nah in iOS Settings. Turn them on there to get your morning call."
            : nil
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Wordmark()
                Text("MORNING CALL\(Text(".").foregroundStyle(Theme.accent))")
                    .font(Theme.display(.largeTitle))
                    .foregroundStyle(Theme.ink)
                    .accessibilityAddTraits(.isHeader)
                Text("One notification a day, built on your phone.").font(.title3.weight(.semibold)).foregroundStyle(
                    Theme.ink)
                Text("Each one uses the newest forecast on this iPhone. Nothing about you is sent anywhere.")
                    .font(.subheadline).foregroundStyle(Theme.inkSecondary)
                if let preferences = model.preferences { settings(preferences) }
                Text(
                    "If iOS doesn't refresh overnight, the notification says how old its forecast is. If it's more than 12 hours old, it asks you to open the app instead of guessing."
                )
                .font(.footnote).foregroundStyle(Theme.inkTertiary)
            }
            .padding(20)
        }
        .background(Theme.ground)
        .accessibilityIdentifier("alerts.screen")
        .task { await notifications.refreshAuthorization() }
    }

    @ViewBuilder func settings(_ preferences: Preferences) -> some View {
        let settings = preferences.notifications
        Card {
            Toggle(isOn: enabledBinding(settings)) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Daily ride notification").font(.headline).foregroundStyle(Theme.ink)
                    Text("Your verdict and the main reason").font(.subheadline).foregroundStyle(Theme.inkTertiary)
                }
            }
            .tint(Theme.accent)
            .accessibilityIdentifier("alerts.toggle")
            if forecast.isLocked, settings.isEnabled {
                Text("Notifications start again once you subscribe. Your settings are kept.")
                    .font(.subheadline).foregroundStyle(Theme.reasonWarm).accessibilityIdentifier("alerts.locked")
            }
            if let note = Self.permissionNote(for: notifications.authorization) {
                Text(note).font(.subheadline).foregroundStyle(Theme.reasonWarm).accessibilityIdentifier("alerts.denied")
                if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                    Link("Open Settings", destination: url).accessibilityIdentifier("alerts.openSettings")
                }
            }
            if settings.isEnabled {
                DatePicker("Time", selection: timeBinding(settings), displayedComponents: .hourAndMinute)
                    .accessibilityIdentifier("alerts.time")
            }
        }
        if settings.isEnabled {
            Card {
                SectionLabel(text: "Which days")
                dayOption(
                    "Days with ride windows", "Your \(preferences.activeProfile.name) windows", .rideWindowDays,
                    settings)
                dayOption("Every day", "Days without windows use daylight hours", .everyDay, settings)
                dayOption("Choose days", "Pick the weekdays yourself", .custom(Set(1...7)), settings)
                if case .custom(let days) = settings.days { WeekdayChips(selected: days) { update(days: .custom($0)) } }
            }
            Card {
                SectionLabel(text: "Check the weather at")
                ForEach(preferences.savedLocations) { place in
                    radio(
                        place.name, "Saved location",
                        selected: preferences.effectiveBackgroundSource == .saved(place.id)
                    ) {
                        setSource(.saved(place.id))
                    }
                }
                radio(
                    "Where I last opened the app", "Kept on this iPhone only",
                    selected: preferences.effectiveBackgroundSource == .lastSeen
                ) {
                    setSource(.lastSeen)
                }
            }
            if let next = notifications.next { preview(next) }
        }
        Card {
            SectionLabel(text: "Ride suggestions")
            Toggle(isOn: suggestionsBinding(preferences.rideSuggestions)) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Suggest clear stretches").font(.headline).foregroundStyle(Theme.ink)
                    Text("Adds them to the outlook, with Add to Calendar. We never read your calendar.")
                        .font(.subheadline).foregroundStyle(Theme.inkTertiary)
                }
            }
            .tint(Theme.accent)
            .accessibilityIdentifier("alerts.suggestions")
        }
    }

    func suggestionsBinding(_ isOn: Bool) -> Binding<Bool> {
        Binding(
            get: { isOn },
            set: { on in
                model.update {
                    $0.rideSuggestions = on
                    $0.sharedModifiedAt = Date()
                }
                Task { await notifications.rebuild() }
            })
    }

    func preview(_ next: PlannedNotification) -> some View {
        Card {
            SectionLabel(
                text: "\(forecast.formatter.shortDate(next.fireDate)), \(forecast.formatter.time(next.fireDate))"
            )
            .accessibilityIdentifier("alerts.previewTime")
            HStack(alignment: .top, spacing: 10) {
                Text("R/N").font(Theme.display(.headline)).foregroundStyle(Theme.accent)
                    .frame(width: 38, height: 38).background(Theme.ground, in: .rect(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 2) {
                    Text("RIDE OR NAH").font(.caption).tracking(1).foregroundStyle(Theme.inkTertiary)
                    Text(next.body).font(.subheadline).foregroundStyle(Theme.ink).accessibilityIdentifier(
                        "alerts.preview")
                }
            }
        }
    }

    func dayOption(
        _ title: String, _ detail: String, _ days: NotificationSettings.Days, _ settings: NotificationSettings
    )
        -> some View
    {
        let selected: Bool =
            switch (settings.days, days) {
            case (.rideWindowDays, .rideWindowDays), (.everyDay, .everyDay), (.custom, .custom): true
            default: false
            }
        return radio(title, detail, selected: selected) { update(days: days) }
    }

    func radio(_ title: String, _ detail: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(selected ? Theme.accent : Theme.inkQuiet)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).foregroundStyle(Theme.ink)
                    Text(detail).font(.caption).foregroundStyle(Theme.inkTertiary)
                }
                Spacer(minLength: 0)
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    func enabledBinding(_ settings: NotificationSettings) -> Binding<Bool> {
        Binding(
            get: { settings.isEnabled },
            set: { on in
                Task {
                    if on {
                        _ = await notifications.enable(at: settings.minutesAfterMidnight)
                    } else {
                        model.update {
                            $0.notifications.isEnabled = false
                            $0.sharedModifiedAt = Date()
                        }
                        await notifications.rebuild()
                    }
                }
            })
    }

    func timeBinding(_ settings: NotificationSettings) -> Binding<Date> {
        let midnight = Calendar.current.startOfDay(for: Date())
        return Binding(
            get: { midnight.addingTimeInterval(Double(settings.minutesAfterMidnight) * 60) },
            set: { date in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
                model.update {
                    $0.notifications.minutesAfterMidnight = (parts.hour ?? 6) * 60 + (parts.minute ?? 30)
                    $0.sharedModifiedAt = Date()
                }
                Task { await notifications.rebuild() }
            })
    }

    func update(days: NotificationSettings.Days) {
        model.update {
            $0.notifications.days = days
            $0.sharedModifiedAt = Date()
        }
        Task { await notifications.rebuild() }
    }

    func setSource(_ source: BackgroundSource) {
        model.update {
            $0.backgroundSource = source
            $0.sharedModifiedAt = Date()
        }
        Task { await notifications.rebuild() }
    }
}

/// Seven weekday buttons, Monday first.
struct WeekdayChips: View {
    let selected: Set<Int>
    let onChange: (Set<Int>) -> Void

    var body: some View {
        HStack(spacing: 6) {
            ForEach(WindowEditor.days, id: \.0) { day, letter in
                let on = selected.contains(day)
                Button(letter) {
                    var days = selected
                    if on { days.remove(day) } else { days.insert(day) }
                    onChange(days)
                }
                .buttonStyle(.plain)
                .frame(width: 36, height: 36)
                .foregroundStyle(on ? Theme.ground : Theme.ink)
                .background(on ? Theme.accent : Theme.card, in: .circle)
                .accessibilityLabel(WindowEditor.names[day] ?? "")
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
    }
}
