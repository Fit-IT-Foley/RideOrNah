# Tasks

Every test that proves a scenario links to it with `// Scenario: <capability>: <scenario name>` on the line above it.

## 1. Presentation (package)

- [x] 1.1 Add a `Presentation` target and test target, with `DisplayFormatter` (temperatures, speeds, percentages, distances, time ranges, relative times, places). Verify formatter tests in both unit systems.
- [x] 1.2 Implement `TodayPresenter`: verdict word, summary, windows, reasons, directions, current conditions, room to limits, daylight, freshness, notes and Unknown causes. Verify tests linked to "Nah from rain", "Clean day", "Done for today", "Anytime rider", "Gust reason", "Clear to the south", "Bad everywhere", "Stale verdict", "Partial coverage", "Offline first launch", "Current hour values", "Comfortable margins" and "Sun times" pass.
- [x] 1.3 Implement `OutlookPresenter` and `DayDetailPresenter`. Verify tests linked to "Outlook confidence marker", "Hour with a breach" and "Missing value in the detail" pass.

## 2. Controller

- [x] 2.1 Implement `ForecastController` (place resolution, snapshot by purpose, evaluation, re-evaluation on preference changes, midnight handling), with debug launch arguments for a fixed clock and fixture weather. Verify app-hosted tests linked to "Pull too soon", "Switching to a smaller radius" and "Midnight with the app open" pass.

## 3. Screens

- [x] 3.1 Build the tab bar, `TodayView` (with chips, compass, windows timeline, reasons, room to limits, daylight and the Unknown state), `WeekView` and `DayDetailView` from the design boards, with attribution on each. Move the debug pipeline screen to Settings. Verify UI tests on fixture weather with a fixed clock show the expected verdict, reasons and outlook, and a test linked to "Day detail attribution" finds the mark and link.
- [x] 3.2 Add a VoiceOver UI test reading the verdict in words, link it to `app-platform: Color-independent state`, and delete that entry from `docs/manual-checks.md`. Verify `make spec-coverage` passes.

## 4. Integration

- [x] 4.1 Verify `make spec-coverage CHANGE=today-and-outlook` passes, and that `make test` and `make test-release` pass on both simulators.
