# Proposal

## Why

This is the screen riders open every morning. It has to answer "can I ride?" at a glance, and explain why when the answer isn't a clean Ride: what's wrong, when, where, and which way is clear. Up to now only a debug screen shows the engine's output.

## What Changes

- Add a Today screen: the verdict word, a one-line summary, each ride window's verdict, the reasons in the rider's units, the direction summary, data freshness, the active profile, the location and today's radius control.
- Explain every Unknown state by its cause (no location, offline, out-of-date forecast, weather service problem), with the next step to take.
- Add pull to refresh, following the manual refresh rules in `weather-data`.
- Add a 7-day outlook, with lower-confidence days marked, and a day detail with the hour-by-hour conditions behind that day's verdict.
- Show weather attribution on every screen that shows weather.
- Remove the DEBUG pipeline screen from `weather-provider`.
- Non-goals: visual design, which comes from the design session. This change implements content and behavior with system components, then adopts the design when it lands. Calendar actions are added by `calendar-suggestions`.

## Capabilities

### New Capabilities
- `verdict-display`: what the Today, outlook and day-detail screens show in every state, and how riders refresh and switch profile, location and radius from them.

### Modified Capabilities
- None.

## Impact

- New app screens and view models. The view models format engine results into localizable text and live in `RideOrNahKit`, so the phrasing is unit-tested.
- Privacy: none new.
- WeatherKit requests: foreground refreshes and pull to refresh, within the `weather-data` intervals and budget. Switching profile, location or radius may need a new sample layout (1, 9 or 17 requests) unless it's already cached.
- Blocked on the design session for final visuals. Behavior can be built and tested before then.
