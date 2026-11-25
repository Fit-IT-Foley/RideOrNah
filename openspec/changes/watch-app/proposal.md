# Proposal

## Why

Riders gear up with their phone in a pocket and a watch on their wrist. A quick look at the watch, or a complication on the watch face, should answer "ride or nah". It should do that without the watch fetching weather itself, which would double WeatherKit costs.

## What Changes

- Add a watchOS 11+ companion app that shows today's verdict, ride windows, the main reasons, the clear directions, and a compact 7-day outlook.
- Add complications for the circular, rectangular, inline and corner watch-face families.
- Have the iPhone send evaluated results (verdicts and reasons, not raw forecasts) to the watch whenever it re-evaluates. The watch makes no weather requests.
- Show the age of the results on the watch. Older than 12 hours, it asks the rider to open the iPhone app instead of showing a verdict.
- Send subscription access state with the results, so the watch locks along with the iPhone.
- Notifications reach the watch through standard iOS notification mirroring, with no extra work.
- Non-goals: a standalone watch app, switching profiles or locations from the watch, and fetching weather on the watch.

## Capabilities

### New Capabilities
- `watch-app`: watch screens and complications, how results reach the watch, freshness, and the locked state.

### Modified Capabilities
- None.

## Impact

- New watchOS app and complication extension targets in `project.yml`, a WatchConnectivity sender on the iPhone, and a receiver and store on the watch.
- Tooling: needs a watchOS 11+ simulator runtime. Only watchOS 10.x is installed today.
- Privacy: results go from the rider's iPhone to their own paired watch. Location names are hidden on complications while the wrist is down or the watch is locked.
- WeatherKit requests: none. The watch reuses the iPhone's evaluations.
