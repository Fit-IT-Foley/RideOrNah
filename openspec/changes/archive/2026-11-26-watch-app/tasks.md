# Tasks

Every test that proves a scenario links to it with `// Scenario: watch-app: <scenario name>` on the line above it.

## 1. Logic (package)

- [x] 1.1 Implement `WatchResults` (Codable, built from the outlook) and `WatchPresenter`. Verify tests linked to "Showing received results", "Past midnight with no update", "Evening on the watch", "Phone left at home", "Lapsed subscription" and "Rectangular complication" pass.
- [x] 1.2 Implement `WatchTimeline.entryDates`. Verify a test linked to "Complication ages without an update" passes.

## 2. iPhone

- [x] 2.1 Implement `WatchSender` behind `WatchSessioning`, and send from `NotificationCoordinator` after each evaluation. Verify an app-hosted test linked to "Sending after a background refresh" passes with a fake session.

## 3. Watch

- [x] 3.1 Add the `RideOrNahWatch` app and `RideOrNahWatchWidgets` complication targets to `project.yml`, embedded in the iPhone app. Verify `make build` builds them.
- [x] 3.2 Implement `WatchStore` (receive, save, reload complications) and the watch screens and complications in `Watch/Shared`, compiled into the iPhone app as well. Verify app-hosted tests linked to "Receiving results" and "Wrist down", and a UI test linked to "Main screen attribution" (the watch screen through `-watchPreview`), pass.
- [x] 3.3 Add the paired-device delivery check to `docs/manual-checks.md`.
- [x] 3.4 Add a watch destination to `make test`, `scripts/create-simulators.sh`, CI and `scripts/merge-when-green.sh`. Verify the watch app's own UI tests, linked to "Showing received results", "Main screen attribution" and "Phone left at home", pass on a watch simulator with `-watchSample` results.

## 4. Integration

- [x] 4.1 Verify `make spec-coverage CHANGE=watch-app` passes, and that `make test` (both iOS simulators and the watch) and `make test-release` pass.
