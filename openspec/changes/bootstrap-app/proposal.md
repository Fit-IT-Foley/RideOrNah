# Proposal

## Why

The repository is empty. Before any feature can be built, we need a buildable iOS project that already enforces the product's hard promises: no backend, no data collection, iOS 26+ with Liquid Glass throughout. Getting these in from the first commit is much cheaper than retrofitting them.

## What Changes

- Create the iOS app target, `RideOrNah`, with iOS 26.0 as the minimum and Swift 6 with complete strict concurrency.
- Create the `RideOrNahKit` local Swift package. It holds all business logic and is testable on macOS with `swift test`.
- Generate the Xcode project from a checked-in `project.yml` (XcodeGen), so project changes are reviewable text.
- Add a shared app-group container now, because widgets and the watch app will read the same cached data later.
- Ship a privacy manifest that declares no tracking and no collected data.
- Add one surface building block that applies Liquid Glass, so surface styling lives in one place.
- Add a placeholder root screen and a UI smoke test so the build and test pipeline works end to end.
- Add a GitHub Actions workflow that builds the app and runs the package tests and the dependency audit on every push and pull request, and runs the UI tests on pull requests or on demand on a chosen iPhone and iOS version.
- Non-goals: no weather, verdict, settings or paywall features, and no visual design. The placeholder screen gets replaced in `today-and-outlook`. No deployment to TestFlight or the App Store: it needs the Apple Developer Program and gets its own change later.

## Capabilities

### New Capabilities
- `app-platform`: supported OS versions, the privacy and no-backend guarantees, Liquid Glass appearance, and baseline accessibility that every later feature inherits.

### Modified Capabilities
- None.

## Impact

- New files: `project.yml`, `Config/*.xcconfig`, `RideOrNah/` (app target), `RideOrNahUITests/`, `Packages/RideOrNahKit/`, `PrivacyInfo.xcprivacy`, `README.md`, `.gitignore`, `.github/workflows/ci.yml`.
- Tooling: XcodeGen (dev-only, already installed via Homebrew). UI tests use the iOS 26 and iOS 27 simulator runtimes already installed, so there's no extra runtime download.
- CI: GitHub Actions on GitHub-hosted macOS runners. The repository is private, so runs draw on the account's included Actions allowance (about 190 macOS minutes a month on GitHub Free). UI tests run only on pull requests and on demand to stay within it.
- Privacy: no permissions requested and no network calls.
- WeatherKit requests: none.
- A bundle ID prefix and Apple Developer team ID are needed later. Both are left as placeholders in a gitignored local xcconfig.
