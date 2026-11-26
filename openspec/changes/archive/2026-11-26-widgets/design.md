# Design

## Context

The app keeps its forecasts in the shared cache, its preferences in app-group defaults, and an access mirror in the shared container, so an extension can read all three. The design canvas doesn't draw widgets, so they use the tokens in `docs/design-system.md`: the ground color, the verdict pills, and the display type. See proposal.md for motivation and the spec for behavior.

## Goals / Non-Goals

**Goals:**
- What each widget says, and when its timeline changes, come from pure code in `Presentation`, tested on the Mac.
- A widget and the app give the same verdict from the same forecast. Both run the same engine on the same cache.

**Non-Goals:**
- Interactive controls, Control Center, Live Activities, and watch complications (`watch-app`).

## Decisions

### `WidgetPresenter` in `Presentation`
`WidgetContent` holds:
- the label ("Today" or "Tomorrow"),
- the verdict and its word, or none when the verdict is Unknown or the widget is locked,
- a short reason: "All clear" for Ride, the most severe breach otherwise, "Forecast too old. Open Ride or Nah." for Unknown, or "Subscribe to see today's call." when locked,
- the forecast age and whether it's stale,
- the place name, which the views mark privacy-sensitive,
- the next three days (weekday, word, lower confidence and a tap URL),
- the widget's own tap URL.

When today's windows are over (`noRideWindowsRemaining` or `noDaylightRemaining`), it shows tomorrow, labelled "Tomorrow".

### `WidgetTimeline` in `Presentation`
`entryDates` returns when a widget's content changes without new data:
- each of today's window ends that's still ahead,
- local midnight,
- the forecast becoming stale (fetch + 3 h),
- the forecast expiring (fetch + 12 h).

The provider re-runs the engine on the same snapshot with `now` set to each date, so ended windows drop out and age is right at every entry. The timeline asks for a reload 2 hours after the last fetch, or at the last entry, whichever is sooner.

### `WidgetLoader` in `Presentation`
`WidgetLoader` does what the extension does on each timeline:
- **Settings and access:** it reads preferences with `PreferencesStore` (app-group defaults) and access from the mirror.
- **Without access:** there's one locked entry and no request.
- **Without preferences or a background place:** there's one entry asking the rider to open the app.
- **With both:** `ForecastStore` runs at the background place with today's radius and the `.widget` purpose, reusing the cache for 2 hours. The `RequestBudget` is shared with the app, and the weather provider is injected, so tests count requests.

### The extension
- **Target:** a `RideOrNahWidgets` app extension. It shares the app group, has the WeatherKit entitlement, and depends on the package libraries.
- **Shared views:** the widget views live in `Widgets/Views` and compile into both the app and the extension, so app-hosted tests can render them. `Theme.swift` compiles into the extension too.
- **One widget:** a single `StaticConfiguration` supports the small, medium, circular, rectangular and inline families.
- **Location names:** they're marked `.privacySensitive()`.

### Keeping widgets current
- `WidgetCenter.shared.reloadAllTimelines()` runs after each forecast refresh, each change to preferences, and each change in access.
- The extension never fetches when the cache is fresh, so a reload after the app's fetch costs no request.

### Tap targets
- **URLs:** `RideURL` (in `Presentation`) builds and parses `rideornah://today` and `rideornah://day/2026-06-11`. The app registers the `rideornah` scheme.
- **Small and Lock Screen widgets** open Today. Each day in the medium widget opens Week with that day's detail pushed, through `AppModel.weekPath`.
- **Attribution:** widgets don't show the Apple Weather mark. They open Today or Day detail, which both show the mark and the attribution link.

## Risks / Trade-offs

- [The simulator only shares the app group when the entitlement is embedded] → The app and the extension both carry it, and `SharedContainer` falls back to a temporary folder, which a widget then sees as "Open Ride or Nah".
- [Widget reload budgets] → Reloads only follow real changes, and timelines carry their own change points.

## Open Questions

- None.
