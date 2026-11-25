# Proposal

## Why

The verdict is only as good as the limits and places behind it. A commuter on a sport bike and a weekend adventure rider have very different tolerances and ride areas. Riders need to set their own limits, ride windows, locations and radius, keep a profile per bike, and have it all follow them across their devices without us running a server.

## What Changes

- Add rider profiles: several named profiles (for example one per bike), exactly one active, each with its own limits for every factor, ride windows, default ride radius, minimum ride duration and wet-road duration.
- Give new profiles sensible default limits, and add riding-style presets for ride windows (Commute, Weekends, Anytime).
- Add a first-run setup that creates the first profile in a few taps, with defaults the rider can accept as they are.
- Add evaluation locations: current location at approximate accuracy with When-In-Use permission only, plus up to 10 saved locations (Home, Work, custom).
- Add ride radius presets (Local, 10 mi / 15 km, 25 mi / 40 km, 50 mi / 80 km, 100 mi / 160 km), a default per profile, and a today-only override that resets at midnight.
- Add a background location source for notifications and widgets: a chosen saved location, or the last location seen while the app was open.
- Add a unit system that follows the device region, with an imperial or metric override.
- Sync profiles, saved locations and settings through the rider's own iCloud when available. The last-seen location, forecast cache and request budget never sync.
- Non-goals: the Today screen (`today-and-outlook`), notification time and days (`daily-notification`), and visual design.

## Capabilities

### New Capabilities
- `rider-profiles`: profiles, limits and their defaults, ride windows, units, first-run setup and iCloud sync of preferences.
- `ride-locations`: current and saved evaluation locations, location permission, ride radius presets and today's override, and the background location source.

### Modified Capabilities
- None.

## Impact

- New `RiderSettings` target in `RideOrNahKit` (models, validation, defaults and sync), plus settings and first-run screens in the app.
- Privacy: adds the When-In-Use location permission, requested at approximate accuracy by default. Saved-location searches go to Apple Maps. Preferences sync through the rider's private iCloud, which we can't access. The last-seen location stays on the device, rounded to 0.01°.
- WeatherKit requests: indirect only. The radius chosen here sets the per-refresh request count defined in `weather-data` (1, 9 or 17).
