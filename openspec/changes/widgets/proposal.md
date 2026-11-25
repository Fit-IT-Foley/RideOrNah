# Proposal

## Why

A glance at the Home or Lock Screen is faster than opening an app, and widgets keep RideOrNah visible every day, which matters for renewals. They have to reuse the app's forecasts, or they'd multiply WeatherKit costs.

## What Changes

- Add Home Screen widgets: small (today's verdict, short reason, freshness) and medium (today plus the next three days).
- Add Lock Screen widgets: circular (verdict), rectangular (verdict and short reason) and inline (verdict and short text).
- Evaluate at the background location source with the active profile and today's radius override, using the shared forecast cache. Fetch only under the widget refresh rules and the daily budget.
- Update the timeline at ride-window boundaries, so ended windows drop off, and right after the app gets new data or settings change.
- Hide location names while the device is locked.
- Show a locked state without weather data when the rider has no access.
- Tapping a widget opens the app on Today, or on the tapped day's detail for the medium widget.
- Non-goals: interactive widget controls, Control Center controls, Live Activities and watch complications (`watch-app`).

## Capabilities

### New Capabilities
- `widgets`: widget families and their content, data source and freshness, refresh behavior, privacy on the Lock Screen, locked state and tap targets.

### Modified Capabilities
- None.

## Impact

- New `RideOrNahWidgets` extension target in `project.yml`, sharing the app group. It uses `WeatherData`, `VerdictEngine`, `RiderSettings` and `Entitlements` from `RideOrNahKit`.
- Privacy: no new permissions. Lock Screen content hides location names while locked.
- WeatherKit requests: widgets fetch only when the cache is older than 2 hours and the budget allows. Usually they make none, because the app or background refresh already fetched.
