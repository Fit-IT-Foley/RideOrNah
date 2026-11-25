# Proposal

## Why

The verdict engine needs real forecasts across the ride radius. WeatherKit is our only variable cost: every request counts against Apple's 500k free monthly calls. Fetching, caching and budgeting have to be designed together, so costs grow with paying riders and not with how often widgets refresh.

## What Changes

- Fetch hourly forecasts, daily sunrise and sunset, and official alerts from WeatherKit for each sample point in the ride radius.
- Lay out sample points: just the evaluation location for a local radius; the location plus eight compass points at the radius otherwise; and an extra inner ring at half the radius for radii of 80 km (49.7 mi) or more.
- Round every coordinate to 0.01° before it's sent or cached.
- Cache forecasts on the device in a container shared by the app and its extensions, reuse them while they're fresh, and delete them after 48 hours.
- Enforce a per-device daily request budget and per-purpose refresh intervals.
- Report partial coverage, offline, service, authorization and budget states distinctly, so the verdict can be Unknown or flagged, never silently wrong.
- Show Apple Weather attribution wherever weather-derived information appears, as WeatherKit's terms require.
- Provide a fixture weather source for debug builds and previews, so development works before the Apple Developer Program is active.
- Non-goals: choosing the evaluation location or radius (`rider-preferences`), and any final UI (`today-and-outlook`). A debug-only screen exercises the pipeline until then.

## Capabilities

### New Capabilities
- `weather-data`: how forecasts are sampled, fetched, cached, budgeted, attributed and reported when something goes wrong.

### Modified Capabilities
- None.

## Impact

- New `WeatherData` target in `RideOrNahKit` (imports WeatherKit and CoreLocation for coordinate types). The app gains the WeatherKit entitlement, an attribution view, and a DEBUG-only pipeline screen.
- Privacy: rounded sample coordinates (about 0.7 mi / 1.1 km precision) are sent to Apple WeatherKit. Nothing else leaves the device. No new permission prompt, because location permission arrives in `rider-preferences`.
- WeatherKit requests: 1 per refresh for a local radius, 9 below 80 km (49.7 mi), 17 at 80 km or more. That's about 800 requests per active rider per month at the default radius, capped at 150 per device per day.
- Needs the Apple Developer Program for live WeatherKit calls. Everything else works with the fixture source.
