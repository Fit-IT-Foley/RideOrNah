# Design

## Context

`ride-verdict-engine` defines `SampleForecast`, `HourConditions`, `AlertInfo` and `DaySun` in SI units. This change fills them from WeatherKit. `SharedContainer` (from `bootstrap-app`) gives the app-group location that the app and widget extension share. The evaluation location and radius are inputs here; `rider-preferences` provides them later. See proposal.md for motivation and `specs/weather-data/spec.md` for the rules.

## Goals / Non-Goals

**Goals:**
- One entry point the rest of the app calls: "give me a forecast snapshot for this location and radius, for this purpose."
- A predictable WeatherKit bill: request counts are deterministic from the layout and refresh rules.
- Everything except the live WeatherKit call is testable on macOS without network access.

**Non-Goals:**
- Background scheduling. `daily-notification` owns `BGAppRefreshTask` and calls this layer.
- Sending forecasts to the watch. `watch-app` sends evaluated results, not raw forecasts.

## Decisions

### A `WeatherProviding` protocol with two implementations
`WeatherProviding.forecast(at: RoundedCoordinate, hours: DateInterval, days: DateInterval) async throws -> PointForecast`, where `PointForecast` holds `[HourConditions]`, `[DaySun]` and `[AlertInfo]?` (nil means alerts are unavailable).
- `WeatherKitProvider` makes one `WeatherService.shared.weather(for:including: .hourly(startDate:endDate:), .daily(startDate:endDate:), .alerts)` call per point.
- `FixtureProvider` loads bundled JSON scenarios. It's compiled only under `#if DEBUG` and is also used by tests and SwiftUI previews.
- **Why:** the store, cache and budget logic are tested against the fixture source with a fake clock. Only the thin WeatherKit mapping needs a live check.

### A thin WeatherKit adapter, with mapping as pure functions
The adapter reads WeatherKit values into the engine's SI fields with `Measurement.converted(to:)`. `ConditionMapper` maps `WeatherCondition` cases to `HazardFlags`:
- thunderstorms (all variants) → `thunderstorm`
- hail → `hail`
- snow, flurries, sleet, freezing rain and drizzle, wintry mix, blizzard, blowing snow → `frozenPrecipitation`
- foggy → `fog`

`WeatherCondition` is a plain enum, so the mapping is fully unit-tested even though `HourWeather` can't be constructed in tests. Alert severity maps one to one to the engine's minor, moderate, severe and extreme levels.

### Sample layout by great-circle destination
`SampleLayout.points(center:radius:)` computes each ring point with the spherical destination formula (Earth radius 6,371 km) at bearings 0°, 45° … 315°, then rounds to 0.01°. It adds the inner ring at radius ÷ 2 when the radius is 80 km (49.7 mi) or more. Each point keeps its `SamplePosition`, so the engine can attribute breaches to directions.

### `ForecastStore` actor orchestrates
`snapshot(center:radius:purpose:) async -> ForecastSnapshot`:
1. Compute the layout.
2. For each point, use the cache if it's younger than the purpose's interval (foreground 60 min, background and widget 2 h, manual 15 min). Otherwise queue a fetch.
3. Reserve budget for the queued fetches. Any fetches that don't fit stay on cache, and the outcome becomes budget-limited.
4. Fetch through a `TaskGroup` with at most 4 requests in flight, recording a per-point success or failure.
5. Write successes to the cache.
6. Return samples, sun times, alerts, `fetchedAt` (the oldest sample used) and the outcome.

`ForecastSnapshot` plus a `ProfileSnapshot` builds the engine's `EvaluationInput`.

### File-per-point cache in the app group's Caches directory
JSON files are stored at `<app group>/Library/Caches/Forecasts/<lat>_<lon>.json`, and each embeds `fetchedAt`.
- Caches directories aren't backed up, which satisfies the spec's backup exclusion.
- Storing `fetchedAt` inside the file avoids file-timestamp APIs, so the privacy manifest needs no new required-reason entry.
- A purge pass deletes files with `fetchedAt` older than 48 h on every store access. It reads a handful of small files, so it doesn't need throttling.

### Request budget in app-group defaults
`RequestBudget` stores `(localDate, count)` in `UserDefaults(suiteName: appGroup)` and resets when the local date changes. Reservation is read-modify-write. A rare race between the app and the widget can overshoot by a few requests. We accept that over cross-process file locking. The budget is a cost guard, not a security boundary.

### WeatherKit request math
| Radius | Points per refresh | ~Refreshes per day | Requests per rider per month |
|---|---|---|---|
| Local | 1 | 3 | ~90 |
| 10–25 mi (16–40 km) | 9 | 3 | ~800 |
| 50–100 mi (80–160 km) | 17 | 3 | ~1,500 |

At the default 25 mi radius, Apple's free 500k monthly calls cover about 600 active riders. Above that, paid tiers cost about $50 per million calls, which is roughly $0.04 per rider per month. The 150-per-day cap bounds the worst case at about 4,500 requests per rider per month.

### Attribution
`WeatherAttributionStore` loads `WeatherService.shared.attribution` once per launch, caching the light and dark combined-mark URLs and `legalPageURL`. A small `WeatherAttributionView` in the app renders the mark for the current color scheme and links to the legal page. The design session restyles it, but it must keep both elements.

### DEBUG pipeline screen
A debug-only screen, reached from the placeholder root, takes a coordinate, radius, source (fixture scenario or live) and a profile with placeholder limits. It shows the request count, outcome, freshness and the engine's verdict, breaches and direction summary. This is how the pipeline gets verified end to end before `today-and-outlook` exists. That change deletes the screen.

## Risks / Trade-offs

- [Apple may count a multi-dataset request as more than one call] → Check the WeatherKit usage page in the developer portal after the first live day. If it does, drop `.daily` and derive sunrise and sunset with an on-device solar calculation.
- [Historical hours (the 12 h lookback) may be unavailable in some regions] → The engine already handles missing lookback by reporting wet roads as partially checked.
- [Budget overshoot from cross-process races] → This is bounded and small; see the budget decision.
- [WeatherKit outage] → The cache plus the Unknown verdict rule mean riders see "can't check right now", never a wrong Ride.

## Open Questions

- Whether a pull-to-refresh hint should say how many refreshes are left today. This is copy only, so it's deferred to `today-and-outlook`.
