# Tasks

Every test that proves a scenario links to it with `// Scenario: <capability>: <scenario name>` on the line above it.

## 1. Model and rules (RiderSettings package target)

- [x] 1.1 Add a `RiderSettings` target and test target depending on `VerdictEngine`, with `Preferences`, `RiderProfile`, `SavedLocation`, `RadiusPreset`, `RidingStyle`, `UnitSystem` and `BackgroundSource`, all `Codable`. Verify a Codable round trip test passes.
- [x] 1.2 Implement `RiderProfile.defaults(named:)` and the riding-style presets. Verify tests linked to "Fresh profile", "Reset to defaults" and "Anytime preset" pass.
- [x] 1.3 Implement profile management: create, rename, duplicate, delete, activate, and engine snapshots. Verify tests linked to "Switching bikes", "Deleting the last profile" and "Deleting the active profile" pass.
- [x] 1.4 Implement `LimitValidator` and `WindowValidator` with rider-facing messages. Verify tests linked to "Soft beyond hard", "Clearing a hard limit" and "Overlapping window" pass, plus range and 4-per-day tests.
- [x] 1.5 Implement unit resolution and display conversion. Verify a test linked to "Override to metric" passes, plus round trips for every converted quantity.
- [x] 1.6 Implement radius presets, labels and today's override. Verify tests linked to "Metric presets", "Switching units keeps the radius", "Long ride today" and "Midnight reset" pass.
- [x] 1.7 Implement saved locations (at most 10, rounded to 0.01°), evaluation location choice, and the background source default and resolution. Verify tests linked to "Adding Home by search", "Limit reached", "Checking work from home", "No location at all", "Default with Home saved", "Last-seen location" and "No source available" pass.

## 2. Persistence and sync

- [x] 2.1 Implement `PreferencesStore` saving to app-group defaults, with the last-seen location and first-run progress under device-only keys. Verify a test linked to "App update" loads a fixture saved by the previous format unchanged.
- [x] 2.2 Implement the iCloud mirror behind `KeyValueSyncing`: per-profile keys, latest-modified wins, tombstones, and the sync toggle. Verify tests linked to "New iPhone", "No iCloud" and "Turning sync off" pass with the in-memory fake, plus a two-device merge test.
- [ ] 2.3 Add the iCloud key-value capability to `project.yml` (needs Developer Program). Verify that preferences changed on one simulator appear on another signed in to the same iCloud account.

## 3. First run and location

- [x] 3.1 Implement `FirstRunFlow` (steps, persisted progress, denied-permission routing, "My Bike" on completion). Verify tests linked to "Quick setup", "Interrupted setup" and "Permission denied" pass.
- [x] 3.2 Implement `LocationService` (When-In-Use only, approximate by default through `NSLocationDefaultAccuracyReduced`, rounding) and the Info.plist strings. Verify a test linked to "Approximate location" passes with a reduced-accuracy fake, and the built Info.plist has the key and purpose string.

## 4. Screens

- [x] 4.1 Add `Theme.swift` and the shared components from `docs/design-system.md`, and make the app always dark. Update the app-platform appearance tests to match. Verify a rendering test linked to "Light system setting" and the live UI test linked to "Switching appearance" pass (the background stays dark in both system modes, and the app keeps running).
- [x] 4.2 Build `FirstRunView` on `FirstRunFlow`. Verify a UI test completes Quick setup on the `RideOrNah iOS 26` and `RideOrNah iOS 27` simulators and lands on the root screen with "My Bike" active.
- [x] 4.3 Build `SettingsView`, `ProfileEditorView` (limits, windows, radius, durations) and `LocationsView` (search, current location, map pin, background source). Verify a UI test edits a limit and adds a saved place by search, and that validation messages appear for invalid input.

## 5. Integration

- [x] 5.1 Verify `make spec-coverage CHANGE=rider-preferences` passes, and that `make test` and `make test-release` pass on both simulators.
