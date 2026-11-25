# Design

## Context

The repository started empty apart from OpenSpec and is hosted privately on GitHub. The machine has Xcode 27.1, XcodeGen and simulator runtimes for iOS 17.x, 26.4 and 27.x. The minimum target is iOS 26.0, so the oldest and newest supported iOS versions can both be tested locally with no extra download. See proposal.md for motivation.

## Goals / Non-Goals

**Goals:**
- One command to generate the project and one to run every test, so agents, humans and CI build the same way.
- A clear line between the app (SwiftUI, Apple frameworks with UI) and `RideOrNahKit` (pure logic, testable on macOS).
- A single place where surfaces get Liquid Glass.
- Every push is built and tested in CI, and the UI tests can run on any chosen iPhone and iOS version without a local simulator.

**Non-Goals:**
- Deployment to TestFlight or the App Store. It needs the Developer Program and an App Store Connect API key, and gets its own change.
- Widget and watch targets. Their own changes add them to `project.yml`.
- Any real visual design.

## Decisions

### Minimum iOS 26.0
The app requires iOS 26.0, and the package targets watchOS 26 to match.
- **Why:** Apple's App Store figures from June 7, 2026 put iOS 26 on 79% of all iPhones and 86% of those introduced in the last four years. iOS 27 runs on exactly the same iPhones (iPhone 11 and later, iPhone SE 2nd and 3rd generation), so requiring it would only block people who haven't updated. iOS 26 gives one appearance instead of two, no `#available` branches, and every iOS 26 API directly.
- **Alternatives:** iOS 18 reaches the remaining fifth of iPhones, mostly 2018-and-older phones or people who don't update, at the cost of a second appearance, a fallback test path and an extra simulator runtime. iOS 27 drops no extra hardware, and its adoption is still early.
- **Revisit:** before launch. Raising the minimum is a one-line change; lowering it means building a fallback.

### Generate the Xcode project with XcodeGen
`project.yml` is the source of truth, and `RideOrNah.xcodeproj` is generated and gitignored.
- **Why:** agents can't click through Xcode's UI. A text spec makes adding targets (widgets, watch) a reviewable diff and avoids `project.pbxproj` merge conflicts.
- **Alternatives:** a hand-made Xcode project is fine for humans but fragile for agent edits. Tuist is more powerful but heavier than we need. A pure Swift Package app can't host app extensions or a watch app.
- **Escape hatch:** if XcodeGen is ever abandoned, commit the last generated project and continue in Xcode.

### Logic lives in a local `RideOrNahKit` package
The package is at `Packages/RideOrNahKit` and has no dependencies. It targets iOS 26, watchOS 26 and macOS 26, so `swift test` runs on the Mac in seconds without a simulator. This change creates only the `SharedContainer` target (app-group container location, with a temporary-directory fallback for tests and previews). Later changes add `VerdictEngine`, `WeatherData` and others as separate targets.

### Concurrency defaults
Swift 6 language mode everywhere. The app target sets `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, because UI code is main-actor by default. Package targets keep the default nonisolated mode, so engine code stays usable from background tasks and extensions.

### Configuration through xcconfig layers
`Config/Base.xcconfig` holds the placeholders `BUNDLE_ID_PREFIX = com.example` and an empty `DEVELOPMENT_TEAM`, and ends with `#include? "Local.xcconfig"`. `Local.xcconfig` is gitignored, and the developer puts their real prefix and team ID there. The app group is derived as `group.$(BUNDLE_ID_PREFIX).rideornah`. This keeps personal identifiers out of git and lets simulator builds work with no account.

### One surface modifier
`View.adaptiveSurface(in:)` is the one place surfaces get their material. It applies `glassEffect(_:in:)`, with no availability check and no fallback, since every supported iOS has Liquid Glass. The name stays: the surface still adapts to light and dark mode, and to whatever the design session adds. System controls (navigation bars, tab bars, sheets, buttons) adopt Liquid Glass automatically when built with the current SDK, so we never set `UIDesignRequiresCompatibility`. The design session will extend this file rather than styling surfaces across the app.

### Privacy manifest contents
`NSPrivacyTracking = false`, empty `NSPrivacyTrackingDomains`, empty `NSPrivacyCollectedDataTypes`. Accessed API reasons: UserDefaults `CA92.1` (app's own defaults) and `1C8F.1` (app-group defaults). Later changes add reasons as they adopt more required-reason APIs, for example file timestamps for the forecast cache.

### Makefile as the command surface
`make project`, `make build`, `make test`, `make test-kit` (`swift test` in the package) and `make audit` (fails if any remote package dependency appears). By default `make test` runs the UI tests on the oldest and newest supported iOS, using the `RideOrNah iOS 26` and `RideOrNah iOS 27` simulators. Setting `DESTINATION` runs them on that one simulator instead, which is how CI picks a device. Test result bundles go to `build/`, which is gitignored. Agents, CI and CLAUDE.md refer to these commands, not raw `xcodebuild` invocations.

### CI on GitHub Actions
`.github/workflows/ci.yml` runs the same Makefile targets as a developer, on GitHub-hosted macOS runners.
- **Why:** it works now, without the Developer Program. It's reviewable YAML in the repository, and `gh workflow run` can start it with a chosen device from the command line. Xcode Cloud stays an option for deployment later.
- **Jobs:** `checks` runs `make audit`, `make test-kit` and `make build` on every push to `main` and every pull request. It runs on `xcode-27`, so it builds with the same Xcode as local work. `ui-tests` runs on pull requests and on demand. By default it runs on the newest iOS 26.x simulator on `macos-26` and the newest iOS 27.x simulator on `xcode-27`. A manual run takes `device` and `ios` inputs and runs on that one simulator, choosing the runner and an Xcode that includes that runtime. A combination the runners don't have fails and lists the simulators they do have.
- **Cost:** the repository is private, and GitHub Free includes about 190 macOS minutes a month. Pushes run only `checks`, superseded runs on the same branch are cancelled, and every job has a timeout.
- **Screenshots:** the UI tests attach screenshots that are always kept. The workflow exports them from the result bundle and uploads them as an artifact kept for 7 days, well inside the 500 MB artifact allowance.
- **Tooling:** the workflow installs XcodeGen with Homebrew, as the README does, and uses only GitHub's own actions.

## Risks / Trade-offs

- [The generated project is gitignored, so a fresh clone can't be opened in Xcode right away] → The README and `make project` make it a single step. The Makefile checks that XcodeGen is installed.
- [Requiring iOS 26 excludes about a fifth of iPhones (June 2026 figures)] → Mostly older phones and people who don't update, who are unlikely subscribers. Recheck the share before launch.
- [Liquid Glass APIs may shift between iOS 26 and 27 SDKs] → They're isolated in one modifier, so any shift means one file to fix.
- [`xcode-27` is a preview runner image with no SLA and possible queueing] → If it proves unreliable, `checks` moves to `macos-26`.
- [The iOS 26 CI job builds with Xcode 26.x, not the 27.x used locally] → The code must keep compiling with Xcode 26 until that job moves to `xcode-27` with a downloaded iOS 26 runtime. Local `make test` covers iOS 26 with Xcode 27.
- [The included Actions minutes run out] → Runs are blocked until the next month, or until a payment method and a budget are added.
- [Placeholder bundle IDs can't use WeatherKit or StoreKit sandbox on device] → That's expected until the Developer Program is active. Simulator builds don't need them.

## Open Questions

- The final bundle ID prefix and team ID. They go in `Config/Local.xcconfig` once the Apple Developer account exists, and nothing in this change depends on their values.
