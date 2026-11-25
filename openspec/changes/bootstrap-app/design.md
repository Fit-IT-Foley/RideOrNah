# Design

## Context

The repository is empty apart from OpenSpec. The machine has Xcode 27.1, XcodeGen and simulator runtimes for iOS 17.x, 26.4 and 27.x. There's no iOS 18 runtime yet, and the minimum target is iOS 18.0, so the fallback appearance can't be tested until one is installed. See proposal.md for motivation.

## Goals / Non-Goals

**Goals:**
- One command to generate the project and one to run every test, so agents and humans build the same way.
- A clear line between the app (SwiftUI, Apple frameworks with UI) and `RideOrNahKit` (pure logic, testable on macOS).
- A single place where Liquid Glass versus fallback is decided.

**Non-Goals:**
- CI. Xcode Cloud can be added once the Developer Program is active.
- Widget and watch targets. Their own changes add them to `project.yml`.
- Any real visual design.

## Decisions

### Generate the Xcode project with XcodeGen
`project.yml` is the source of truth, and `RideOrNah.xcodeproj` is generated and gitignored.
- **Why:** agents can't click through Xcode's UI. A text spec makes adding targets (widgets, watch) a reviewable diff and avoids `project.pbxproj` merge conflicts.
- **Alternatives:** a hand-made Xcode project is fine for humans but fragile for agent edits. Tuist is more powerful but heavier than we need. A pure Swift Package app can't host app extensions or a watch app.
- **Escape hatch:** if XcodeGen is ever abandoned, commit the last generated project and continue in Xcode.

### Logic lives in a local `RideOrNahKit` package
The package is at `Packages/RideOrNahKit` and has no dependencies. It targets iOS 18, watchOS 11 and macOS 15, so `swift test` runs on the Mac in seconds without a simulator. This change creates only the `SharedContainer` target (app-group container location, with a temporary-directory fallback for tests and previews). Later changes add `VerdictEngine`, `WeatherData` and others as separate targets.

### Concurrency defaults
Swift 6 language mode everywhere. The app target sets `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, because UI code is main-actor by default. Package targets keep the default nonisolated mode, so engine code stays usable from background tasks and extensions.

### Configuration through xcconfig layers
`Config/Base.xcconfig` holds the placeholders `BUNDLE_ID_PREFIX = com.example` and an empty `DEVELOPMENT_TEAM`, and ends with `#include? "Local.xcconfig"`. `Local.xcconfig` is gitignored, and the developer puts their real prefix and team ID there. The app group is derived as `group.$(BUNDLE_ID_PREFIX).rideornah`. This keeps personal identifiers out of git and lets simulator builds work with no account.

### One adaptive surface modifier
`View.adaptiveSurface(in:)` is the only place that checks `#available(iOS 26, *)`. It applies `glassEffect(_:in:)` on iOS 26+ and `background(.regularMaterial, in:)` before that. System controls (navigation bars, tab bars, sheets, buttons) adopt Liquid Glass automatically when built with the current SDK, so we never set `UIDesignRequiresCompatibility`. The design session will extend this file rather than scattering availability checks across the app.

### Privacy manifest contents
`NSPrivacyTracking = false`, empty `NSPrivacyTrackingDomains`, empty `NSPrivacyCollectedDataTypes`. Accessed API reasons: UserDefaults `CA92.1` (app's own defaults) and `1C8F.1` (app-group defaults). Later changes add reasons as they adopt more required-reason APIs, for example file timestamps for the forecast cache.

### Makefile as the command surface
`make project`, `make build`, `make test` (UI tests on the iOS 18 and latest iOS simulators), `make test-kit` (`swift test` in the package) and `make audit` (fails if any remote package dependency appears). Agents and CLAUDE.md refer to these commands, not raw `xcodebuild` invocations.

## Risks / Trade-offs

- [The generated project is gitignored, so a fresh clone can't be opened in Xcode right away] → The README and `make project` make it a single step. The Makefile checks that XcodeGen is installed.
- [The iOS 18 runtime is a large download] → It's needed only to check the fallback path. Day-to-day work uses the latest simulator.
- [Liquid Glass APIs may shift between iOS 26 and 27 SDKs] → They're isolated in one modifier, so any shift means one file to fix.
- [Placeholder bundle IDs can't use WeatherKit or StoreKit sandbox on device] → That's expected until the Developer Program is active. Simulator builds don't need them.

## Open Questions

- The final bundle ID prefix and team ID. They go in `Config/Local.xcconfig` once the Apple Developer account exists, and nothing in this change depends on their values.
