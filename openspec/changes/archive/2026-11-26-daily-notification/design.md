# Design

## Context

`ForecastController` already fetches and evaluates for Today. `Preferences` holds the profile, places and background location source. The design canvas draws the notification settings (the Alerts tab) and the notifications themselves (the Push board). See proposal.md for motivation and the spec for behavior.

## Goals / Non-Goals

**Goals:**
- Notification text and timing come from a pure planner, tested on the Mac.
- A notification always goes out, even if iOS never runs a background refresh.

**Non-Goals:**
- The calendar action (`calendar-suggestions`) and the ride-suggestions toggle on the Alerts board.

## Decisions

### Settings live in `Preferences`, read tolerantly
`NotificationSettings` holds `isEnabled` (off until the rider opts in), `minutesAfterMidnight` (default 390, which is 06:30) and `days`: `.rideWindowDays` (the default), `.everyDay`, or `.custom(weekdays)`.
- It's a new `Preferences` field, so it syncs with the rest.
- `Preferences` decodes it with `decodeIfPresent` and a default, so preferences saved by earlier versions still load. The "App update" fixture keeps passing.
- Resolution: ride-window days fall back to every day when the profile has no windows (the Anytime preset).

### `NotificationPlanner` in `Presentation`
Given the settings, profile, outlook, fetch time, now and formatter, it returns the next 3 `PlannedNotification`s (an ID, a fire date, the body and the day). Each body follows the Push board:
- `Ride: clear 7–9 AM and 4–6 PM.`
- `Maybe: gusts up to 34 mph to the west, 4–6 PM. Clear to the south.`
- `Nah: rain likely 7–9 AM (80%). Clear to the SE, S and SW.`

Forecast age at delivery decides the rest:
- More than 3 hours old: the body adds `Based on last night's forecast.` (if it was fetched the previous evening), or `Based on a forecast from 5 hours earlier.`
- More than 12 hours old, or Unknown: `Open Ride or Nah for today's verdict. The last forecast is too old to call it.`

### Scheduling and refresh in the app
- `NotificationScheduler` replaces every pending `ride.` request with the plan's calendar triggers, through a `NotificationCentering` protocol, so tests use a fake.
- `NotificationCoordinator` rebuilds after every forecast refresh and settings change. It evaluates at the background location source with the day's radius, reusing the forecast cache through `ForecastStore` with the background purpose. That means about one extra refresh a day at most, and none when the place is Today's.
- A SwiftUI `.backgroundTask(.appRefresh)` handler, with the identifier in `BGTaskSchedulerPermittedIdentifiers`, refreshes and rebuilds. Each rebuild asks iOS for the next refresh starting 90 minutes before the next notification.

### Screens
- The Alerts tab follows the Notification settings board:
  - the daily notification toggle and time,
  - which days (three choices, with weekday chips for custom),
  - "Check the weather at" (the background source),
  - a preview of the next notification.
- When permission is denied, the tab explains it and links to the app's notification settings in iOS Settings.
- First-run setup gains a notification step after location. It can turn notifications on at a chosen time, or skip without asking permission.
- Tapping a notification selects the Today tab.

## Risks / Trade-offs

- [Background refresh timing is up to iOS] → It's covered by always-scheduled notifications plus honest age notes.
- [The rider changes time zones] → Calendar triggers use the device's current calendar and are rebuilt on every launch and refresh.

## Open Questions

- None.
