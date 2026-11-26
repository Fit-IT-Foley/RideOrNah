# Tasks

Every test that proves a scenario links to it with `// Scenario: widgets: <scenario name>` on the line above it.

## 1. Logic (package)

- [x] 1.1 Implement `WidgetPresenter` and `RideURL`. Verify tests linked to "Medium widget", "Evening", "Old data" and "Lapsed subscription" pass.
- [x] 1.2 Implement `WidgetTimeline.entryDates`. Verify a test linked to "Data ages without a refresh" passes.
- [x] 1.3 Implement `WidgetLoader` with an injected provider. Verify tests linked to "Matching verdicts" and "After opening the app" (no request when the app's cache is fresh) pass.

## 2. App and extension

- [x] 2.1 Add the `RideOrNahWidgets` extension to `project.yml`: app group, WeatherKit, the widget bundle, and shared views in `Widgets/Views` compiled into the app too.
- [x] 2.2 Build the widget views for all five families, and mark place names privacy-sensitive. Verify an app-hosted rendering test linked to "Locked device" passes: privacy redaction changes only a view that shows a place.
- [x] 2.3 Register the `rideornah` URL scheme, and open Today or a day's detail from it. Reload widget timelines after refreshes, preference changes and access changes. Verify UI tests linked to "Tapping Thursday" and "Attribution through the app" pass.
- [x] 2.4 Add the attribution review to `docs/manual-checks.md`, linked to "Attribution review".

## 3. Integration

- [x] 3.1 Verify `make spec-coverage CHANGE=widgets` passes, and that `make test` and `make test-release` pass on both simulators, with the extension embedded.
