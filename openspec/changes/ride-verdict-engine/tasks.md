# Tasks

Every test that proves a scenario links to it with `// Scenario: ride-verdict: <scenario name>` on the line above the test. The scenario names each task lists are the ones its tests must link.

## 1. Core types

- [ ] 1.1 Add a `VerdictEngine` target and `VerdictEngineTests` target to `RideOrNahKit`, with Foundation as the only import. Verify `make test-kit` builds both.
- [ ] 1.2 Define `Verdict`, `Severity`, `Factor`, `FactorLimit`, `Limits`, `RideWindow`, `ProfileSnapshot`, `CompassDirection` and `SamplePosition` as `Sendable` and `Codable` value types. Verify tests cover verdict ordering, Unknown's precedence rules, and Codable round-trips.
- [ ] 1.3 Define `HourConditions`, `HazardFlags`, `SampleForecast`, `AlertInfo`, `DaySun` and `EvaluationInput`. Add a test fixture builder (for example `.hours(from:count:) { $0.precipitationChance = 0.7 }`) in the test target. Verify a fixture-building test passes.

## 2. Factor evaluators

- [ ] 2.1 Implement the precipitation evaluator (chance, intensity, thunderstorm or hail always hard). Verify tests linked to "Chance exceeds the hard limit", "Low chance but heavy intensity" and "Thunderstorm" pass.
- [ ] 2.2 Implement the cold, heat (feels-like) and humidity evaluators. Verify tests linked to "Cold morning" and "Muggy afternoon" pass, plus tests at the exact threshold boundaries.
- [ ] 2.3 Implement the wind and gust evaluators. Verify tests linked to "Calm average, strong gusts" and "Gust data missing" pass.
- [ ] 2.4 Implement the UV and visibility evaluators, including the fog fallback. Verify tests linked to "High UV", "Dense fog" and "Fog without visibility data" pass.
- [ ] 2.5 Implement the wet-roads evaluator, with lookback across preceding hours and partial-check reporting. Verify tests linked to "Rain ended before the commute" and "No lookback data" pass.
- [ ] 2.6 Implement the ice evaluator (frozen precipitation, or at or below the profile's threshold while wet or at 95%+ humidity). Verify tests linked to "Cold and damp" and "Cold but dry" pass.
- [ ] 2.7 Implement the alerts evaluator (severity mapping, active period, current-day fallback, not-checked state). Verify tests linked to "Severe thunderstorm warning", "Moderate alert", "Minor alert", "Alert ends before the window", "Alert without an active period" and "Alerts unsupported in the region" pass.
- [ ] 2.8 Implement the shared handling of disabled factors, unset limits and missing values. Verify tests linked to "Value exactly at the limit", "Disabled factor", "Soft-only factor", "UV missing" and "Temperature missing here" pass.

## 3. Aggregation

- [ ] 3.1 Implement evaluated-hour selection: window overlap, the daylight fallback with the "no ride window scheduled" flag, ended windows and hours today, "no ride windows remaining", "no daylight remaining" and missing sun times. Verify tests linked to "Window boundaries", "Rain outside the windows", "Weekend-only rider on a Tuesday", "Afternoon check", "After sunset", "Missing sun times", "Morning window already over" and "All windows over" pass, plus a DST-transition day.
- [ ] 3.2 Implement window and day verdicts across all sample points (worst case, Unknown rules, partial coverage). Verify tests linked to "Clean forecast", "Only soft breaches", "Any hard breach", "One bad window", "Storm at the edge of the radius", "Missing ring point" and "A known Nah outranks Unknown" pass.
- [ ] 3.3 Implement breach merging and ordering. Verify a test linked to "Merged time range" passes, and that ordering is by severity, then by start time.
- [ ] 3.4 Implement the direction summary (inner and outer rings merged, Unknown for directions without data, none for a local radius). Verify tests linked to "Rain to the north only", "Missing direction" and "Local radius" pass.
- [ ] 3.5 Implement `FreshnessPolicy` (today 3 h stale / 12 h expired, later days 24 h expired). Verify tests linked to "Outdated forecast", "Stale but usable" and "Later days expire" pass.

## 4. Outlook, opportunities and ranges

- [ ] 4.1 Implement the 7-day evaluation with lower confidence on days four to seven. Verify a test linked to "Outlook confidence" passes.
- [ ] 4.2 Implement ride-opportunity detection (daylight only, every sample with data and clear, minimum duration, no ended hours, at most three per day longest first, none on Unknown or partial-coverage days). Verify tests linked to "Saturday afternoon gap", "Too short", "Busy good day", "Ended hours" and "No opportunities without data" pass.
- [ ] 4.3 Implement time-range evaluation on the window pipeline. Verify a test linked to "Added ride turns rainy" passes.

## 5. Integration checks and docs

- [ ] 5.1 Add seeded property tests: loosening any limit never makes a verdict more severe, adding a sample point never makes it less severe, and evaluating the same input twice gives identical results (linked to "Repeat evaluation"). Verify they pass over at least 500 generated inputs.
- [ ] 5.2 Write `Packages/RideOrNahKit/Sources/VerdictEngine/README.md` describing the inputs, outputs, units and freshness rules, with one worked example. Verify the example's input, copied into a test, produces the output the README shows.
- [ ] 5.3 Verify `make spec-coverage CHANGE=ride-verdict-engine` passes, so every ride-verdict scenario is linked to a test.
