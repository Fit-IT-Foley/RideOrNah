# Design

## Context

`VerdictEngine` takes a `ProfileSnapshot` (limits, windows, minimum ride duration) and `WeatherData` takes a center coordinate and radius in metres. Nothing yet stores what the rider wants. The design canvas draws the profile, location and radius chips on Today and the notification settings, but no settings, profile or first-run screens. Those follow `docs/design-system.md`, which this change introduces along with `Theme.swift`. See proposal.md for motivation and the two specs for behavior.

## Goals / Non-Goals

**Goals:**
- One preferences model, testable on macOS, that the app, widgets and (through the phone) the watch all read.
- iCloud sync that can't lose a profile to a race, testable without iCloud.
- A first-run flow short enough to finish in under a minute with defaults.

**Non-Goals:**
- The Today screen and its chips (`today-and-outlook`), and notification settings (`daily-notification`).

## Decisions

### A `RiderSettings` package target owns the model
`Preferences` holds `[RiderProfile]`, `activeProfileID`, `[SavedLocation]`, `evaluationLocation` (current or a saved ID), `backgroundSource`, `unitOverride`, `syncEnabled` and `todayRadius` (an override with its local date). A `RiderProfile` holds an `id`, `name`, `modifiedAt`, `Limits` (the engine's own type, so there's no translation layer), `[RideWindow]`, `radius: RadiusPreset`, `preset`, and `minimumRideDuration`. Pure functions cover defaults, presets, validation, unit display values, radius resolution and the background-source default, and all are unit-tested.

### Defaults and presets as data
`RiderProfile.defaults(named:)` builds the spec's table in SI: 3 °C ice threshold, 0.3/0.6 precipitation chance, and so on. The presets are `RidingStyle.commute`, `.weekends` and `.anytime`; Anytime has no windows. Each limit's imperial value in the spec is its SI value rounded for display.

### Radius presets are stored kilometres
`RadiusPreset` is `local(0)`, `16`, `40`, `80` and `160` km. The imperial label is the kilometres converted and rounded to the nearest 5 mi (10, 25, 50, 100), so switching units never changes the radius. The 80 km preset is exactly `SampleLayout.innerRingThreshold`.

### Storage: app-group defaults, plus an iCloud mirror
- `PreferencesStore` saves `Preferences` as JSON under one key in app-group `UserDefaults`, so widgets read the same data.
- The last-seen location and first-run progress live under separate device-only keys, and are never in `Preferences`.
- With sync on, each profile is mirrored to `NSUbiquitousKeyValueStore` as `profile.<id>`, plus `shared`, which holds locations, the active profile, units and the background source. External changes merge per profile by `modifiedAt`, and the latest wins. Deletions are tombstones (`deleted.<id>` with a date), so a deleted profile doesn't come back from another device.
- The store talks to a `KeyValueSyncing` protocol. Tests use an in-memory fake, and a test simulates a second device writing to it.

### Units
`UnitSystem.resolved(override:locale:)` uses `Locale.measurementSystem`: US gives imperial, and everything else metric (UK riders get metric by default and can override). Display conversion is a pure function per factor (°C↔°F, m/s↔mph or km/h, m↔mi or km, mm/h↔in/h). Entering a value converts back to SI before validation.

### Validation
`LimitValidator` returns a typed error with a rider-facing message:
- The soft limit is beyond the hard limit (direction-aware).
- A value is outside its physical range: chance 0–100%, intensity 0–50 mm/h, temperatures −40 to 60 °C, humidity 0–100%, wind 0–60 m/s, UV 0–15, visibility 0–20 km.
- A duration is out of range: wet roads 0–12 h, minimum ride 0.5–8 h.

`WindowValidator` rejects:
- an end that isn't after its start,
- windows that overlap on a shared weekday,
- more than 4 windows in a day.

### Location
`LocationService` wraps `CLLocationManager`:
- It requests When-In-Use permission only after the explanation screen.
- Info.plist sets `NSLocationDefaultAccuracyReduced` to YES, so approximate accuracy is the default.
- Every coordinate is rounded to 0.01° before it's stored or used.

Saved places are added by:
- search, through `MKLocalSearchCompleter` and `MKLocalSearch` (network: Apple Maps),
- the current location,
- a pin dropped on a `Map` with `MapReader`.

### First-run flow as a state machine
`FirstRunFlow` steps through preset → limits review → location explanation → (later changes add steps here) → done. Each answer updates a draft profile. Its `step` is persisted on every change, so quitting resumes at the same step. A denied permission routes to "add a saved location". Finishing creates the "My Bike" profile from the draft, and the flow's logic is unit-tested apart from the screens.

### Screens
- `FirstRunView` presents the flow's steps.
- `SettingsView` (from a gear button in the header) lists Profiles, Locations, Units and iCloud sync.
- `ProfileEditorView` edits name, limits per factor, ride windows, default radius and durations.
- `LocationsView` handles saved places and the background source.

They're SwiftUI screens built from `Theme` components, and each one's logic sits in an `@Observable` model tested in the package.

## Risks / Trade-offs

- [iCloud key-value storage is limited to 1 MB and 1,024 keys] → A profile is about 2 KB, so even 100 profiles fit easily.
- [iCloud KVS needs the iCloud capability on the App ID] → The sync logic is tested with the fake. The live check is marked "(needs Developer Program)".
- [MapKit search sends the rider's typed text to Apple Maps] → It's disclosed in the location explanation and allowed by the updated network-destinations requirement.

## Open Questions

- None.
