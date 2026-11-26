# Tasks

## 1. Core types

- [ ] 1.1 Add a `VerdictEngine` target and `VerdictEngineTests` target to `RideOrNahKit`, with Foundation as the only import. Verify `make test-kit` builds both.
- [ ] 1.2 Define `Verdict`, `Severity`, `Factor`, `FactorLimit`, `Limits`, `RideWindow`, `ProfileSnapshot`, `CompassDirection` and `SamplePosition` as `Sendable` and `Codable` value types. Verify tests cover verdict ordering, Unknown's precedence rules, and Codable round-trips.
- [ ] 1.3 Define `HourConditions`, `HazardFlags`, `SampleForecast`, `AlertInfo`, `DaySun` and `EvaluationInput`. Add a test fixture builder (for example `.hours(from:count:) { $0.precipitationChance = 0.7 }`) in the test target. Verify a fixture-building test passes.

## 2. Factor evaluators

- [ ] 2.1 Implement the precipitation evaluator (chance, intensity, thunderstorm or hail always hard). Verify tests match the spec's "Precipitation and storms" scenarios.
- [ ] 2.2 Implement the cold, heat (feels-like) and humidity evaluators. Verify tests match the "Temperature and humidity" scenarios, including exact-threshold boundaries.
- [ ] 2.3 Implement the wind and gust evaluators, with "gusts not checked" when gust data is missing. Verify tests match the "Wind and gusts" scenarios.
- [ ] 2.4 Implement the UV and visibility evaluators, including the fog fallback when visibility is missing. Verify tests match the UV and "Visibility and fog" scenarios.
- [ ] 2.5 Implement the wet-roads evaluator with lookback across preceding hours and partial-check reporting. Verify tests match the "Wet roads after rain" scenarios.
- [ ] 2.6 Implement the ice evaluator (frozen precipitation, or at or below the threshold while wet or at 95%+ humidity). Verify tests match the "Ice risk" scenarios.
- [ ] 2.7 Implement the alerts evaluator (severity mapping, active period, current-day fallback, not-checked state). Verify tests match the "Severe weather alerts" scenarios.
- [ ] 2.8 Implement the disabled-factor and unset-limit handling shared by all evaluators. Verify tests match the "Factor limits are configurable per factor" scenarios.

## 3. Aggregation

- [ ] 3.1 Implement evaluated-hour selection: window overlap, the daylight fallback with the "no ride window scheduled" flag, ended windows today, and "no ride windows remaining". Verify tests match the spec's ride-window, no-window and ended-window scenarios, including a DST-transition day.
- [ ] 3.2 Implement window and day verdicts across all sample points (worst case, Unknown rules, partial coverage). Verify tests match the "Worst case across the ride radius" and "Missing and stale data never yields Ride" scenarios.
- [ ] 3.3 Implement breach merging and ordering. Verify a test matches the "Merged time range" scenario, and that ordering is by severity, then by start time.
- [ ] 3.4 Implement the direction summary, merging inner and outer rings, with none for a local radius. Verify tests match the "Direction summary" scenarios.
- [ ] 3.5 Implement `FreshnessPolicy` (today 3 h stale / 12 h expired, later days 24 h expired). Verify tests match the "Outdated forecast" and "Stale but usable" scenarios.

## 4. Outlook and opportunities

- [ ] 4.1 Implement the 7-day evaluation with lower confidence on days four to seven. Verify a test matches the "Outlook confidence" scenario.
- [ ] 4.2 Implement ride-opportunity detection (daylight-only, all samples clear, minimum duration, no past hours, at most three per day, longest first). Verify tests match the "Ride opportunities" scenarios.

## 5. Integration checks and docs

- [ ] 5.1 Add seeded property tests: loosening any limit never makes a verdict more severe, adding a sample point never makes it less severe, and evaluating the same input twice gives identical results. Verify they pass over at least 500 generated inputs.
- [ ] 5.2 Write `Packages/RideOrNahKit/Sources/VerdictEngine/README.md` describing the inputs, outputs, units and freshness rules. Verify `make spec-coverage CHANGE=ride-verdict-engine` passes, so every ride-verdict scenario is linked to a test.
