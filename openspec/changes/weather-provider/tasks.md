# Tasks

## 1. Sampling geometry

- [ ] 1.1 Add a `WeatherData` target and a `WeatherDataTests` target to `RideOrNahKit`, depending on `VerdictEngine` and `SharedContainer`. Verify `make test-kit` builds both.
- [ ] 1.2 Implement `RoundedCoordinate` (0.01° rounding) and `SampleLayout` (center only for local; eight ring points; inner ring at 80 km / 49.7 mi and above, so both the 50 mi and 80 km presets qualify). Verify tests match the spec's layout and rounding scenarios, with ring distances within 1% of the radius.

## 2. Provider abstraction and fixtures

- [ ] 2.1 Define `WeatherProviding`, `PointForecast` and `ForecastOutcome` (complete, partial, offline, serviceUnavailable, notAuthorized, budgetLimited). Verify a compile-level test with a stub provider.
- [ ] 2.2 Implement `FixtureProvider` (DEBUG only) with JSON scenarios: clear day, afternoon rain, storm to the north, freezing morning and gusty. Verify tests load each scenario and confirm the storm scenario flags thunderstorms only on the N, NE and NW points.

## 3. WeatherKit adapter

- [ ] 3.1 Implement `ConditionMapper` (`WeatherCondition` to `HazardFlags`) and alert severity mapping. Verify tests cover every `WeatherCondition` case, failing if a new case appears unmapped.
- [ ] 3.2 Implement `WeatherKitProvider` with SI conversion and nil for missing alerts. Verify on a simulator (needs Developer Program) that a 25 mi fetch returns 9 samples with hourly data starting 12 h before today.
- [ ] 3.3 Add the WeatherKit capability to `project.yml` and the entitlements (needs Developer Program). Verify that a signed simulator build gets no authorization errors.

## 4. Cache, budget and store

- [ ] 4.1 Implement `ForecastCache` (JSON per rounded point in the app group's `Library/Caches/Forecasts`, with embedded `fetchedAt` and a 48 h purge). Verify tests for write and read, the expiry purge, and that the directory is under Caches.
- [ ] 4.2 Implement `RequestBudget` (150 per local day in app-group defaults, with reservation and reset). Verify tests for exhaustion, partial reservation and day rollover across a DST change.
- [ ] 4.3 Implement the `ForecastStore` actor (per-purpose intervals, budget reservation, at most 4 concurrent fetches, per-point outcomes). Verify tests with `FixtureProvider` and a fake clock that match each "Forecast reuse and refresh intervals", "Daily request budget" and "Failure reporting" scenario, including exact request counts.
- [ ] 4.4 Add a `ForecastSnapshot` to `EvaluationInput` builder. Verify a test that a fixture snapshot evaluates to the expected verdict through `VerdictEngine`.

## 5. App wiring, attribution and docs

- [ ] 5.1 Implement `WeatherAttributionStore` and `WeatherAttributionView` (mark for the current appearance plus a legal link). Verify with SwiftUI previews in light and dark, and that the link opens Apple's attribution page on a simulator (needs Developer Program for live attribution data).
- [ ] 5.2 Add the DEBUG pipeline screen (inputs: coordinate, radius, source, placeholder profile; outputs: request count, outcome, freshness, verdict, breaches, direction summary). Verify on the latest iOS simulator with each fixture scenario that the verdicts match the fixture expectations.
- [ ] 5.3 Confirm release builds exclude the fixture source. Verify `make build` in Release configuration and confirm `FixtureProvider` symbols are absent with `nm`.
- [ ] 5.4 Document WeatherKit setup (App ID capability, propagation delay, fixture launch arguments) and the request-math table in `README.md`. Verify the launch arguments as written select a fixture scenario.
