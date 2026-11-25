# Proposal

## Why

The verdict is the product: everything else (notifications, widgets, calendar, watch) only delivers it. The decision rules need to be exact, explainable and heavily tested before any UI depends on them. A rider who's told "Ride" and gets caught in a storm won't renew.

## What Changes

- Add a pure-logic verdict engine that turns hourly forecasts for a set of sample points, plus a rider's limits and ride windows, into Ride, Maybe, Nah or Unknown.
- Judge only the hours the rider actually rides (their ride windows), falling back to daylight hours on days without a window.
- Support every v1 factor: precipitation, thunderstorms and hail, cold, heat (feels-like), humidity, sustained wind, gusts, UV, wet roads after rain, ice risk, low visibility and fog, and official severe weather alerts. Each factor has an optional soft limit, an optional hard limit, and an on/off switch.
- Use the worst sample across the ride radius for the verdict, and report which compass directions are clear.
- Explain every verdict: which factor, how bad, when, where, and against which limit.
- Produce a 7-day outlook with lower-confidence days marked, and find ride opportunities (good stretches of daylight) for calendar suggestions.
- Refuse to say Ride on missing or out-of-date data.
- Non-goals: fetching weather (`weather-provider`), storing limits or providing defaults (`rider-preferences`), and turning results into on-screen text (`today-and-outlook`).

## Capabilities

### New Capabilities
- `ride-verdict`: how forecasts, limits and ride windows become a verdict with reasons, direction summary, 7-day outlook and ride opportunities.

### Modified Capabilities
- None.

## Impact

- New `VerdictEngine` target in `RideOrNahKit`, depending on Foundation only. No app UI changes.
- Privacy: none. The engine runs on data already on the device.
- WeatherKit requests: none. The engine consumes forecasts and never fetches them.
