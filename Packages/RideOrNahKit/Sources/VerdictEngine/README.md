# VerdictEngine

Turns hourly forecasts across the ride radius, a rider's limits and ride windows, and the current time into Ride, Maybe, Nah or Unknown. It's pure and synchronous: no networking, no storage, no UI, and the same input always gives the same output. The rules are in `openspec/specs/ride-verdict/spec.md` (until archived, `openspec/changes/ride-verdict-engine/specs/ride-verdict/spec.md`). Each scenario there has a test linked to it with a `// Scenario: ride-verdict: <name>` comment.

## Inputs

`EvaluationInput` holds:

- `now` and a `calendar`. The calendar's time zone interprets ride windows, so pass the device's.
- `profile`: the rider's `Limits`, `RideWindow`s and minimum ride duration.
- `samples`: one `SampleForecast` per sample point, from the center plus up to 16 ring points. Pass a point whose request failed with no hours, so it's reported as missing instead of silently ignored.
- `alerts`, plus `alertsAvailable` (false when the source offers no alerts for the area).
- `sun`: sunrise and sunset per day. Days without ride windows are judged on daylight.
- `fetchedAt`: the oldest fetch time among the samples.

All values are SI: °C, m/s, metres, mm/h, and fractions (0–1) for chance and humidity. Convert for display with `Measurement`, never inside the engine. Hours start on the hour, and an hour missing precipitation chance, temperature, feels-like or sustained wind counts as having no data.

## Outputs

- `VerdictEngine.outlook(for:)` returns seven `DayEvaluation`s, today first. Each has the verdict (or a `status` saying nothing is left today), per-window results, merged `Breach`es, the direction summary, `coverage`, `freshness`, `confidence`, ride `opportunities`, and the factors not checked or only partly checked.
- `VerdictEngine.evaluate(range:in:)` judges any time range, such as a ride already added to the calendar, like a ride window.

## Freshness

Ages are measured from `fetchedAt`. Today goes stale after 3 hours and becomes Unknown after 12. Later days become Unknown after 24 hours. The thresholds live in `FreshnessPolicy.standard`.

## Worked example

Monday's 07:00–09:00 commute, with 34 mph (15.2 m/s) gusts to the west at 08:00 and a soft gust limit of 30 mph (13.4 m/s):

```swift
var calendar = Calendar(identifier: .gregorian)
calendar.timeZone = TimeZone(identifier: "America/New_York")!
let monday = calendar.date(from: DateComponents(year: 2026, month: 6, day: 8, hour: 6))!

func hours(gustAt8: Double) -> [HourConditions] {
    (0..<4).map { offset in
        let start = monday.addingTimeInterval(Double(offset + 1) * 3600)  // 07:00 to 10:00
        return HourConditions(
            start: start, temperature: 20, feelsLike: 20, humidity: 0.5, windSpeed: 4,
            windGust: offset == 1 ? gustAt8 : 6, uvIndex: 3, visibility: 10_000,
            precipitationChance: 0, precipitationIntensity: 0)
    }
}

let input = EvaluationInput(
    now: monday, calendar: calendar,
    profile: ProfileSnapshot(
        limits: Limits(gusts: ThresholdLimit(soft: 13.4, hard: 17.9)),
        windows: [RideWindow(weekdays: [2], from: (7, 0), to: (9, 0))]),
    samples: [
        SampleForecast(position: .center, hours: hours(gustAt8: 6)),
        SampleForecast(position: .ring(.w, .outer), hours: hours(gustAt8: 15.2)),
    ],
    sun: [], fetchedAt: monday)

let today = VerdictEngine.outlook(for: input)[0]
// today.verdict == .maybe
// today.breaches == [Breach(factor: .gusts, severity: .soft, worstValue: 15.2, limit: 13.4,
//                           range: 08:00–09:00, positions: [.ring(.w, .outer)])]
// today.clearDirections == []  (west has a breach; it's the only ring point)
```

`ReadmeExampleTests` runs this exact example.
