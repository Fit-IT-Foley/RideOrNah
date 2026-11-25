# Design

## Context

`bootstrap-app` provides the `RideOrNahKit` package with no logic yet. This change adds the `VerdictEngine` target. The engine knows nothing about WeatherKit, storage or UI: `weather-provider` maps WeatherKit data into the engine's input types, `rider-preferences` supplies limits and defaults, and `today-and-outlook` turns results into words. See proposal.md for motivation and `specs/ride-verdict/spec.md` for the rules.

## Goals / Non-Goals

**Goals:**
- A pure, synchronous, deterministic function from inputs to results, so every spec scenario is a fast unit test.
- Results structured enough that the UI, notifications, widgets and watch can each phrase them differently and in any language.

**Non-Goals:**
- User-facing strings. The engine returns structured data, and the UI layer localizes it.
- Sub-hourly precision. WeatherKit's hourly forecast is the finest data we budget for.

## Decisions

### Input model in SI units, independent of WeatherKit
`EvaluationInput` holds `now`, a `Calendar` (time zone), a `ProfileSnapshot` (limits, ride windows, minimum ride duration), an array of `SampleForecast`, an array of `AlertInfo`, per-day sunrise and sunset, and `fetchedAt`.
- `SampleForecast` has a `SamplePosition` (`.center`, or `.ring(direction: CompassDirection, ring: .inner/.outer)`) and an array of `HourConditions`.
- `HourConditions` uses plain `Double`s in SI units: temperature °C, feels-like °C, humidity 0–1, wind and gust m/s, visibility m, precipitation chance 0–1, intensity mm/h. Optional fields mean the value is missing. A `HazardFlags` option set holds `thunderstorm`, `hail`, `frozenPrecipitation` and `fog`.
- **Why:** the engine stays testable without WeatherKit types, which can't be constructed in tests. Units are converted once, at display time, with `Measurement`.
- **Alternative:** `Measurement<Unit…>` everywhere. Rejected, because it adds noise in hundreds of comparisons and fixtures for no safety gain once the boundary converts.

### One evaluator per factor
`Factor` is a `CaseIterable` enum: precipitation, cold, heat, humidity, wind, gusts, uv, wetRoads, ice, visibility, alerts. Each factor has a small evaluator that takes an hour, the sample's preceding hours (for wet roads and ice) and its limits, and returns an optional `Finding(factor, severity, value, limit, hour, position)`.
- `Limits` stores one `FactorLimit` per factor: `enabled`, `soft: Double?`, `hard: Double?`, plus a direction (`.above` or `.below`) fixed per factor. Precipitation carries two pairs (chance and intensity), and wet roads carries a duration and a level.
- **Why:** each spec requirement maps to exactly one evaluator and its tests, and adding a v2 factor (daylight, air quality) is additive.

### Aggregation pipeline
1. Choose evaluated hours per day: ride windows overlapping hours, or the daylight fallback. Drop ended windows today.
2. Run every enabled evaluator for every evaluated hour at every sample point, producing findings.
3. Window verdict = the max severity of its findings, or Unknown if the center sample has no hours in the window.
4. Day verdict = the max of its window verdicts, with Unknown losing to Nah and beating Ride and Maybe, per the spec.
5. Merge findings into `Breach`es keyed by (factor, severity, position group) over consecutive hours, keeping the worst value.
6. Direction summary = the max severity per `CompassDirection`, across inner and outer ring points.
7. Apply freshness last: if the forecast is too old, the verdict becomes Unknown, and breaches are kept for context.

### Freshness thresholds are named constants
Today: stale after 3 hours, expired after 12. Later days: expired after 24. These live in `FreshnessPolicy` with the spec values as defaults, so notification copy and tests can reference them by name.

### Opportunities from a per-hour "all clear" mask
For each day, build a boolean per daylight hour that's true when no sample has any finding. Then take maximal runs of at least the minimum duration, excluding past hours, and keep the three longest. This reuses step 2's findings, so it's cheap.

### Time zone handling
Windows are wall-clock times (`weekday`, start and end minutes after midnight, with no window crossing midnight), resolved against the injected `Calendar`. Tests inject fixed time zones, including a DST-transition day, so time-zone behavior is covered.

## Risks / Trade-offs

- [The device time zone may differ from the forecast location's time zone when the evaluation location is far away] → This is acceptable for v1, because riders evaluate places they can ride to. Revisit if saved locations far from home become common.
- [Hourly granularity can miss a short storm between hours] → WeatherKit hourly values already represent the hour. Thunderstorm flags and alerts catch most short severe events.
- [The worst-case rule may feel too pessimistic with large radii] → The direction summary tells riders where it's clear. Tune the radius defaults in `rider-preferences` if beta riders find it too strict.

## Open Questions

- None that affect this change. Default limit values belong to `rider-preferences`.
