# Design

## Context

The iPhone already evaluates the outlook at the background location source for notifications and widgets. The watch gets that evaluation, not raw forecasts, so it never asks WeatherKit for anything. The design canvas doesn't draw the watch, so it uses the tokens in `docs/design-system.md`. See proposal.md for motivation and the spec for behavior.

## Goals / Non-Goals

**Goals:**
- **Pure logic:** what the watch shows, and when its complications change, come from pure code in `Presentation`, tested on the Mac.
- **One format:** the iPhone sends one small Codable value. The watch stores the last one it received and works from it.

**Non-Goals:**
- A standalone watch app, changing profiles or places from the watch, and fetching weather on the watch.

## Decisions

### `WatchResults` in `Presentation`
`WatchResults` is a Codable value holding:
- the fetch time, whether the rider has access, and the profile and place names,
- the radius label (nil for Local),
- one `WatchDay` per outlook date.

Each `WatchDay` carries:
- the day, its verdict, and its summary reason,
- its windows (start, end, verdict and top reason),
- its direction text, and whether it's lower confidence.

`WatchResults.make(...)` builds it on the iPhone from the outlook with the same phrasing as Today. It holds the evaluated words and times only, with no forecast values, and it's well under WatchConnectivity's application-context limit.

### `WatchPresenter` and `WatchTimeline` in `Presentation`
`WatchPresenter.content(results, now)` picks the entry for the current local date. It drops windows that have ended and recomputes the day's verdict as the worst of the remaining windows.
- **No windows left today:** it shows tomorrow, labelled "Tomorrow".
- **Older than 3 hours:** it marks the verdict as based on an older forecast.
- **Older than 12 hours, or never received:** it shows no verdict and says "Open Ride or Nah on your iPhone."
- **No access:** it shows "Subscribe on your iPhone to see the call."

`WatchTimeline.entryDates` returns today's window ends, midnight, fetch + 3 h and fetch + 12 h, like the widget timeline.

### Sending from the iPhone
`WatchSender` sends `WatchResults` through a `WatchSessioning` protocol, so tests use a fake. The live session uses `WCSession.updateApplicationContext`, where the newest results replace older ones.
- **When it sends:** `NotificationCoordinator` already evaluates the background place after every refresh, including background refreshes, and after every settings and access change. It hands that same outlook to `WatchSender`. That's one evaluation, and no extra weather request.
- **Without a paired watch or the watch app,** sending is skipped.

### The watch app
- **Targets:** `RideOrNahWatch` is a watchOS 26 app with `WKCompanionAppBundleIdentifier` set to the iPhone app, embedded in the iPhone app. `RideOrNahWatchWidgets` is a WidgetKit extension for the circular, rectangular, inline and corner complications.
- **Receiving:** `WatchStore` receives the application context, saves it to the watch's shared defaults (an app group shared with the complications), and calls `WidgetCenter.shared.reloadAllTimelines()`.
- **Main screen:** today's verdict, windows, reasons, directions, the six-day outlook, the profile and place, the forecast age, and the Apple Weather mark at the bottom.
- **Complications:** they read the stored results and build a timeline from `WatchTimeline`. Place names are `.privacySensitive()`. Tapping opens the app.
- **Shared views:** the watch views use only SwiftUI that also builds for iOS, and they live in `Watch/Shared`, compiled into the iPhone app too. That way app-hosted tests can render them on any simulator, and `-watchPreview` shows the watch screen on the iPhone for a UI test.

### Tooling
- **Builds:** the watchOS 27 SDK ships with Xcode, so the watch targets build and `make build` covers them.
- **Watch-side tests:** `RideOrNahWatchUITests` runs the watch app on a watch simulator. A debug-only `-watchSample` launch argument hands the store sample results, as if the iPhone sent them, and `-fixedNow` stops the clock. `make test` runs it on watchOS 27 after the iPhone tests, and CI runs it on watchOS 26, the oldest supported. App-hosted iPhone tests still render the watch views, and `-watchPreview` still shows the watch screen on the iPhone.

## Risks / Trade-offs

- [WatchConnectivity delivery can't be tested in a simulator pair reliably] → The sender and receiver are tested on each side. Real delivery between paired devices goes in `docs/manual-checks.md`.
- [Watch tests cost CI time] → One watch job per pull request, on watchOS 26 only. Local `make test` covers watchOS 27.

## Open Questions

- None.
