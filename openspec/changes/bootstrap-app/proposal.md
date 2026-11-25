# Proposal

## Why

The repository is empty. Before any feature can be built, we need a buildable iOS project that already enforces the product's hard promises: no backend, no data collection, iOS 18+ with Liquid Glass on iOS 26+. Getting these in from the first commit is much cheaper than retrofitting them.

## What Changes

- Create the iOS app target, `RideOrNah`, with iOS 18.0 as the minimum and Swift 6 with complete strict concurrency.
- Create the `RideOrNahKit` local Swift package. It holds all business logic and is testable on macOS with `swift test`.
- Generate the Xcode project from a checked-in `project.yml` (XcodeGen), so project changes are reviewable text.
- Add a shared app-group container now, because widgets and the watch app will read the same cached data later.
- Ship a privacy manifest that declares no tracking and no collected data.
- Add one adaptive-surface building block: Liquid Glass on iOS 26+, standard material on iOS 18–25.
- Add a placeholder root screen and a UI smoke test so the build and test pipeline works end to end.
- Non-goals: no weather, verdict, settings or paywall features, and no visual design. The placeholder screen gets replaced in `today-and-outlook`.

## Capabilities

### New Capabilities
- `app-platform`: supported OS versions, the privacy and no-backend guarantees, adaptive Liquid Glass appearance, and baseline accessibility that every later feature inherits.

### Modified Capabilities
- None.

## Impact

- New files: `project.yml`, `Config/*.xcconfig`, `RideOrNah/` (app target), `RideOrNahUITests/`, `Packages/RideOrNahKit/`, `PrivacyInfo.xcprivacy`, `README.md`, `.gitignore`.
- Tooling: XcodeGen (dev-only, already installed via Homebrew) and an iOS 18 simulator runtime for testing the pre-Liquid Glass fallback.
- Privacy: no permissions requested and no network calls.
- WeatherKit requests: none.
- A bundle ID prefix and Apple Developer team ID are needed later. Both are left as placeholders in a gitignored local xcconfig.
