# RideOrNah

iOS app (iOS 26+) that tells motorcycle riders Ride, Maybe or Nah for today, from weather limits they set. Subscription only, no backend, no data collection. Product rules and the build plan live in [`openspec/`](openspec/config.yaml); see [`CLAUDE.md`](CLAUDE.md) for the spec-driven workflow.

## Requirements

- Xcode 27.1 or later
- [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`
- For `make test`: iOS 26.x and iOS 27.x simulator runtimes (Xcode → Settings → Components)

## Getting started

```sh
make project     # generate RideOrNah.xcodeproj from project.yml
open RideOrNah.xcodeproj
```

`RideOrNah.xcodeproj` is generated and gitignored. Change targets and settings in `project.yml`, then run `make project` again.

## Commands

| Command | What it does |
|---|---|
| `make project` | Generate the Xcode project from `project.yml` |
| `make build` | Build the app for the iOS Simulator (`CONFIGURATION=Release` for a release build) |
| `make simulators` | Create the `RideOrNah iOS 26` and `RideOrNah iOS 27` simulators if they're missing |
| `make test` | Create those simulators if needed, then run the app-hosted unit tests and UI tests on both. `DESTINATION=...` runs them on one simulator instead |
| `make test-release` | Run the Release-build UI check (debug-only code such as fixture weather must be absent) on the same simulators |
| `make test-kit` | Run the `RideOrNahKit` package tests on this Mac (no simulator needed) |
| `make audit` | Fail if any remote package dependency has been added |
| `make lint` | Fail if any Swift file doesn't match the style in `.swift-format` |
| `make format` | Rewrite Swift files to match `.swift-format` |
| `make validate-specs` | Run `openspec validate --all --strict` (uses `npx` if `openspec` isn't installed) |
| `make spec-coverage` | Fail if a spec scenario has no linked test or manual check. `CHANGE=<name>` also requires that change's scenarios |
| `make asc-status`, `make asc-apps`, `make asc-bundle-ids` | Read-only App Store Connect checks through `asc` (see [`docs/app-store-connect.md`](docs/app-store-connect.md)) |

To run the UI tests on one simulator, look it up by device name and iOS version (a major like `26` picks the newest installed 26.x):

```sh
make test DESTINATION="$(scripts/find-simulator.sh 'iPhone 17' 26)"
```

Test results, including screenshots of the launch screen and the largest text size, go to `build/UITests.xcresult`.

## Weather

Forecasts come from Apple WeatherKit through `Packages/RideOrNahKit/Sources/WeatherData`, and the verdict rules live in `Sources/VerdictEngine`.

**Fixture weather (debug builds only).** Debug builds can use canned weather instead of WeatherKit: `clearDay`, `afternoonRain`, `stormToTheNorth`, `freezingMorning` and `gusty`. These launch arguments open the debug weather pipeline screen on a fixture and evaluate it straight away, with no network requests:

```sh
-openWeatherDebug YES -weatherSource fixture -weatherScenario stormToTheNorth
```

Add them in Xcode under Product → Scheme → Edit Scheme → Run → Arguments, or pass them to `XCUIApplication().launchArguments` in a UI test. Release builds compile the fixtures and the debug screen out, and `make test-release` checks that.

**Other debug launch arguments**, for UI tests and trying things out:

| Argument | Effect |
|---|---|
| `-skipFirstRun YES` | Starts with a ready "My Bike" commuter profile instead of setup |
| `-resetPreferences YES` | Clears saved preferences on launch, so setup runs again |
| `-locationStub granted` or `denied` | Answers the location prompt without the system dialog |
| `-searchStub YES` | Returns canned place-search results instead of asking Apple Maps |

**WeatherKit setup (needs the Developer Program).** Live forecasts need the WeatherKit capability on the app's App ID (Certificates, Identifiers & Profiles → Identifiers → the app → WeatherKit), and the `com.apple.developer.weatherkit` entitlement, which `project.yml` already sets. A newly enabled capability can take about 30 minutes to start working. Until then, requests fail as "not authorized", and the app reports that rather than guessing.

**Request budget.** Each refresh requests one point for a local radius, 9 points below 80 km (49.7 mi), and 17 from 80 km up. Cached forecasts are reused for 60 minutes in the foreground, 2 hours in the background and in widgets, and 15 minutes after a pull to refresh. Each device makes at most 150 requests a day.

| Radius | Requests per refresh | Requests per rider per month (about 3 refreshes a day) |
|---|---|---|
| Local | 1 | ~90 |
| 10–25 mi (16–40 km) | 9 | ~800 |
| 50–100 mi (80–160 km) | 17 | ~1,500 |

At the default 25 mi radius, Apple's free 500,000 calls a month cover about 600 active riders. Above that, paid tiers cost about $50 per million calls.

## Linking tests to specs

Every scenario in `openspec/specs/` must be proven by a test. A test says which scenarios it proves with a comment on its own line directly above it, naming the capability and the scenario exactly as the spec writes it:

```swift
// Scenario: app-platform: Install on the oldest supported OS
@MainActor
func testLaunchShowsPlaceholderTitle() {
```

A scenario that neither a Mac nor a simulator can check, such as App Store behavior or a real device's network traffic, goes in [`docs/manual-checks.md`](docs/manual-checks.md) instead, with how and when to check it.

`make spec-coverage` fails when a scenario has neither, or when a test or manual check names a scenario that doesn't exist (for example after a rename). Tests can link to scenarios in active changes before they're archived. Run `make spec-coverage CHANGE=<name>` before archiving a change, to require its scenarios too.

## Continuous integration

[`.github/workflows/ci.yml`](.github/workflows/ci.yml) runs the same make targets on GitHub-hosted runners:

- Every push to `main` and every pull request: `make audit`, `make lint`, `make test-kit` and `make build` on macOS, and `make validate-specs` and `make spec-coverage` on Linux.
- Every pull request: the app-hosted unit tests and UI tests on the newest iOS 26 and iOS 27 simulators. Test screenshots are uploaded as an artifact kept for 7 days.
- On demand: the UI tests on any simulator the runners have.

```sh
gh workflow run ci.yml -f device="iPhone 17 Pro" -f ios=27.2
gh run watch
```

`ios` takes a major version (`26`) or an exact one (`26.5`). Leave it out to run both defaults. iOS 26 runs on the `macos-26` runner and iOS 27 on `xcode-27`. If the runner doesn't have that device and version, the run fails and lists the iOS simulators it does have.

The repository is private, so CI draws on the account's included Actions minutes (about 190 macOS minutes a month on GitHub Free). That's why pushes skip the UI tests.

### Merging

GitHub Free can't protect branches on a private repository, so nothing on GitHub stops a merge with failing or missing checks. Merge pull requests with the script instead of the Merge button:

```sh
scripts/merge-when-green.sh --wait <pr-number>
```

It waits for CI, then squash-merges only if every check in its `EXPECTED_CHECKS` list passed on the pull request's latest commit. A missing, skipped or cancelled check counts as a failure. If you rename a CI job or change the default UI test simulators, update that list.

To stop direct pushes to `main` from your Mac, turn on the repository's git hooks once per clone:

```sh
git config core.hooksPath .githooks
```

## Signing and your Apple Developer account

Simulator builds work without an account. For device builds, WeatherKit and StoreKit sandbox testing, copy the example config and fill in your values:

```sh
cp Config/Local.xcconfig.example Config/Local.xcconfig
```

`Config/Local.xcconfig` sets `BUNDLE_ID_PREFIX` and `DEVELOPMENT_TEAM`. It's gitignored, so personal identifiers stay out of the repository. The app group is derived from the prefix as `group.<prefix>.rideornah`.

App Store Connect is driven from the command line with an API key, not a browser sign-in. See [`docs/app-store-connect.md`](docs/app-store-connect.md) for setup, key handling and the `make asc-*` commands.

## Layout

- `RideOrNah/`: the iOS app (SwiftUI). `DesignSystem/AdaptiveSurface.swift` is the one place surfaces get Liquid Glass.
- `RideOrNahUITests/`: UI tests.
- `Packages/RideOrNahKit/`: business logic with no UI framework dependencies, tested with Swift Testing.
- `Config/`: xcconfig files. `scripts/`: helpers used by the Makefile and CI, and the merge script. `.githooks/`: optional git hooks. `.github/workflows/`: CI.
