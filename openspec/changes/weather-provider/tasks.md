# Tasks

Every test that proves a scenario links to it with `// Scenario: weather-data: <scenario name>` on the line above the test. The scenario names each task lists are the ones its tests must link.

## 1. Sampling geometry

- [ ] 1.1 Add a `WeatherData` target and a `WeatherDataTests` target to `RideOrNahKit`, depending on `VerdictEngine` and `SharedContainer`. Verify `make test-kit` builds both.
- [ ] 1.2 Implement `RoundedCoordinate` (0.01° rounding) and `SampleLayout` (center only for local; eight ring points; inner ring at 80 km / 49.7 mi and above). Verify tests linked to "Default radius", "Large radius", "Local radius" and "Rounded request" pass, with ring distances within 1% of the radius.

## 2. Provider abstraction and fixtures

- [ ] 2.1 Define `WeatherProviding`, `PointForecast` and `ForecastOutcome` (complete, partial, offline, serviceUnavailable, notAuthorized, budgetLimited, alreadyCurrent). Verify a compile-level test with a stub provider.
- [ ] 2.2 Implement `FixtureProvider` (DEBUG only) with JSON scenarios: clear day, afternoon rain, storm to the north, freezing morning and gusty. Verify tests load each scenario and confirm the storm scenario flags thunderstorms only on the N, NE and NW points.

## 3. WeatherKit adapter

- [ ] 3.1 Implement `ConditionMapper` (`WeatherCondition` to `HazardFlags`) and alert severity mapping. Verify tests cover every `WeatherCondition` case, failing if a new case appears unmapped.
- [ ] 3.2 Implement `WeatherKitProvider` with SI conversion and nil for missing alerts (needs Developer Program). Verify on the `RideOrNah iOS 26` simulator that a 25 mi fetch returns 9 samples with hourly data starting 12 h before today.
- [ ] 3.3 Add the WeatherKit capability to `project.yml` and the entitlements (needs Developer Program). Verify that a signed simulator build gets no authorization errors.

## 4. Cache, budget and store

- [ ] 4.1 Implement `ForecastCache` (JSON per rounded point in the app group's `Library/Caches/Forecasts`, with embedded `fetchedAt` and a 48 h purge on every access). Verify tests for write and read and for the Caches location pass, and a test linked to "Old cache entries" passes.
- [ ] 4.2 Implement `RequestBudget` (150 per local day in app-group defaults, with reservation and reset). Verify tests linked to "Budget exhausted" and "New day" pass, including a day rollover across a DST change.
- [ ] 4.3 Implement the `ForecastStore` actor (per-purpose intervals, budget reservation, at most 4 concurrent fetches, per-point outcomes). Verify tests with `FixtureProvider` and a fake clock, linked to "Reopening the app", "Pull to refresh too soon", "Widget refresh", "Offline with cache", "Offline without cache" and "Some ring points fail", assert exact request counts.
- [ ] 4.4 Add store tests with a recording provider: the hourly range it requests starts 12 hours before today ("Lookback for wet roads"), and a point whose provider returns no alerts is marked alerts-unavailable ("Alerts unsupported in the region"). Verify they pass.
- [ ] 4.5 Add a test where an app store and a widget store share one container and cache, and the widget store makes no request right after the app store fetched. Verify a test linked to "Widget after app refresh" passes.
- [ ] 4.6 Add a `ForecastSnapshot` to `EvaluationInput` builder. Verify a test that a fixture snapshot evaluates to the expected verdict through `VerdictEngine`.

## 5. App wiring, attribution and docs

- [ ] 5.1 Implement `WeatherAttributionStore` and `WeatherAttributionView` (mark for the current appearance plus a legal link). In fixture mode, the store serves a bundled test mark with Apple's legal URL. Verify a UI test linked to "Verdict screen" finds the mark and the link on the DEBUG pipeline screen. Live attribution data needs the Developer Program, so check it on the `RideOrNah iOS 26` simulator (needs Developer Program).
- [ ] 5.2 Add the DEBUG pipeline screen (inputs: coordinate, radius, source, placeholder profile; outputs: request count, outcome, freshness, verdict, breaches, direction summary). Verify a UI test linked to "Debug fixture" launches with the "storm to the north" fixture and finds thunderstorm breaches to the north and a request count of 0. It must pass with `make test` on the `RideOrNah iOS 26` and `RideOrNah iOS 27` simulators.
- [ ] 5.3 Let `make test` run against a Release build (`CONFIGURATION=Release`). Add a UI test linked to "Release build" that launches with the fixture arguments and finds no debug weather screen and no fixture data. Verify it passes with `make test CONFIGURATION=Release`.
- [ ] 5.4 Document WeatherKit setup (App ID capability, propagation delay, fixture launch arguments) and the request-math table in `README.md`. Verify the launch arguments as written select a fixture scenario.
- [ ] 5.5 Verify `make spec-coverage CHANGE=weather-provider` passes, so every weather-data scenario is linked to a test.
