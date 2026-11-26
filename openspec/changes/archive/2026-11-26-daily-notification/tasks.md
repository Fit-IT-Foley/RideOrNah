# Tasks

Every test that proves a scenario links to it with `// Scenario: ride-notifications: <scenario name>` on the line above it.

## 1. Settings and planner (package)

- [x] 1.1 Add `NotificationSettings` to `Preferences` with tolerant decoding and day resolution. Verify tests linked to "Weekend rider default" and "Anytime rider default" pass, and the rider-profiles "App update" fixture still loads.
- [x] 1.2 Add the notification step to `FirstRunFlow` (turn on at a time, or skip). Verify tests linked to "Turning it on during setup" and "Skipping the step" pass, and the existing first-run tests are updated to pass through the new step.
- [x] 1.3 Implement `NotificationPlanner` (next 3 selected days, bodies, age notes, the too-old fallback). Verify tests linked to "Maybe morning", "Ride morning", "No background time granted", "Last night's forecast" and "Too old" pass.

## 2. App

- [x] 2.1 Implement `NotificationScheduler`, `NotificationCoordinator` and background refresh (permitted identifier, a request 90 minutes before the next notification, a handler that refreshes and rebuilds). Verify app-hosted tests linked to "Settings change" and "Refresh runs in time" pass with a fake notification center.
- [x] 2.2 Build the Alerts tab and the first-run notification step from the design, including the denied-permission explanation and link, and route notification taps to Today. Verify app-hosted tests linked to "Denied permission" and "Tap" pass, and a UI test changes the notification time.

## 3. Integration

- [x] 3.1 Verify `make spec-coverage CHANGE=daily-notification` passes, and that `make test` and `make test-release` pass on both simulators.
