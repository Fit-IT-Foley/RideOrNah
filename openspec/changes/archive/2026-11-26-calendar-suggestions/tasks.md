# Tasks

Every test that proves a scenario links to it with `// Scenario: ride-calendar: <scenario name>` on the line above it.

## 1. Logic (package)

- [x] 1.1 Add `Preferences.rideSuggestions` (off by default, read tolerantly), and keep added rides in `PreferencesStore`'s device-only defaults, pruned once their day passes. Verify a test linked to "Default off" passes, and the rider-profiles "App update" fixture still loads.
- [x] 1.2 Implement `SuggestionPresenter`. Verify tests linked to "Clear Saturday afternoon", "Stale forecast" and "Already added" pass.
- [x] 1.3 Implement `CalendarDraft`: title, range, place and notes. Verify a package test checks the draft for Saturday 11:00–17:30.
- [x] 1.4 Implement `AddedRideCheck`. Verify tests linked to "Rain moves in" and "Can't check an added ride" pass.
- [x] 1.5 Add `calendarRange` to `PlannedNotification`. Verify tests linked to "Morning action" (the range is the longest opportunity) and "Old forecast, no action" pass.

## 2. App

- [x] 2.1 Build `CalendarEditor` (`EKEventEditViewController`, with no permission request) and the `-calendarStub` debug override. Record saved rides, and leave cancelled ones untouched.
- [x] 2.2 Add the Ride suggestions card to Alerts, suggestion pills to Week, and the Ride suggestion card to Day detail, from the boards. Show added-ride notices on Today. Verify UI tests linked to "Saving a ride" and "Cancelling" pass, and that a UI test opens the real editor with no permission alert.
- [x] 2.3 Register the `ride.calendar` notification category and action, and route it to Today with the editor pre-filled. Verify an app-hosted test linked to "Morning action" opens the editor for the notification's range.

## 3. Integration

- [x] 3.1 Verify `make spec-coverage CHANGE=calendar-suggestions` passes, and that `make test` and `make test-release` pass on both simulators.
