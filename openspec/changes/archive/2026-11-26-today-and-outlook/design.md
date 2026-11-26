# Design

## Context

`VerdictEngine` produces a 7-day outlook from an `EvaluationInput`. `WeatherData`'s `ForecastStore` turns a center and radius into a `ForecastSnapshot`. `RiderSettings` holds the profile, places, units and today's radius. The design canvas's "Ride or Nah" page draws these screens: Today (Nah and Ride states), Next 7 days, and Day detail. They follow `docs/design-system.md`. See proposal.md for motivation and the spec for behavior.

## Goals / Non-Goals

**Goals:**
- Every string on these screens comes from tested code. Views only lay out what the presentation layer gives them.
- UI tests are deterministic: fixture weather and a fixed clock, both debug-only.

**Non-Goals:**
- Calendar suggestions in the Week list (`calendar-suggestions`) and the Alerts tab (`daily-notification`).
- The canvas's Share and Messages boards, which are marked "not in spec yet".

## Decisions

### A `Presentation` package target formats everything
`TodayPresenter`, `OutlookPresenter` and `DayDetailPresenter` take the engine's `DayEvaluation`s, the `ForecastSnapshot`, the resolved place, the active profile, the current time and a `DisplayFormatter`. They return plain content structs: verdict word, summary, window rows, reason rows, direction text, current conditions, room to limits, daylight, freshness, notes, and the Unknown cause and action.

`DisplayFormatter` wraps units, calendar and locale. It covers temperatures (`54°`), speeds, percentages, distances, time ranges (`4–7 PM`, `11 AM–5:30 PM`), relative times (`Now`, `In 8 h`, `Ended`) and places:
- `here` for the evaluation location alone.
- `to the west` for one direction.
- `to the N, NE and NW` for several.
- `here and to the N`, combined.

### Summary and reason phrasing per factor
The summary names the most severe breach's factor, its worst value and its time range. For example:
- `Rain likely 7–9 AM (80%)`
- `Gusts up to 34 mph, 4–6 PM`
- `Cold: 46° at 7 AM`

A reason row has three parts:
- A title with the worst value: `Gusts up to 34 mph`.
- The limit: `(your limit 30 mph)`.
- A detail with time and places: `4–7 PM · to the west`.

Alerts use the alert's own name.

### `ForecastController` owns fetching and evaluation
An `@Observable` controller in the app:
- resolves the evaluation place (current location or saved),
- asks `ForecastStore` for a snapshot with the right purpose (foreground on appear and scene activation, manual on pull to refresh),
- evaluates it with the active profile and today's radius,
- re-evaluates without fetching when the profile, location or radius changes and the cache covers the new choice.

It listens for `NSCalendarDayChanged` to clear today's radius override and re-evaluate at midnight. The clock and the weather source are injected. In debug builds, the launch arguments `-fixedNow <ISO 8601>` and `-weatherSource fixture` set them.

### Screens
- A two-tab `TabView`, Today and Week. The Alerts tab arrives with `daily-notification`.
- `TodayView` follows the Today boards:
  - the wordmark and settings button,
  - profile, location and radius chips (each opens a picker sheet),
  - the place, date and updated line,
  - the "Today's call" label, the huge verdict word, and the italic reason,
  - three current-condition figures,
  - the direction compass card,
  - the ride-windows card with a day timeline,
  - "Why nah" or "Why maybe" with HARD and SOFT tags,
  - "Room to your limits" and "Daylight" on Ride days,
  - "See the next 7 days", and the attribution footer.
- `WeekView` and `DayDetailView` follow their boards.
- An Unknown verdict replaces the hero with the cause and its action.
- Verdict words carry accessibility labels, so color never stands alone. A VoiceOver UI test checks this and replaces the `app-platform: Color-independent state` manual check.

### Attribution
`WeatherAttributionView` sits at the bottom of every weather screen. Live builds load the mark from WeatherKit once. Fixture and unauthorized builds show the stand-in label with Apple's legal link.

## Risks / Trade-offs

- [The giant verdict word at large text sizes] → It's sized with `@ScaledMetric` and `minimumScaleFactor`, and scrolls with the rest of the screen.
- [Live WeatherKit isn't authorized until the capability is on the App ID] → Live builds show the "not authorized" Unknown state until then. Debug builds and tests use fixtures.

## Open Questions

- None.
