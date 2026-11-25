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
| `make test` | Create those simulators if needed, then run the UI tests on both. `DESTINATION=...` runs them on one simulator instead |
| `make test-kit` | Run the `RideOrNahKit` package tests on this Mac (no simulator needed) |
| `make audit` | Fail if any remote package dependency has been added |

To run the UI tests on one simulator, look it up by device name and iOS version (a major like `26` picks the newest installed 26.x):

```sh
make test DESTINATION="$(scripts/find-simulator.sh 'iPhone 17' 26)"
```

Test results, including a screenshot of the launch screen, go to `build/UITests.xcresult`.

## Continuous integration

[`.github/workflows/ci.yml`](.github/workflows/ci.yml) runs the same make targets on GitHub-hosted macOS runners:

- Every push to `main` and every pull request: `make audit`, `make test-kit` and `make build`.
- Every pull request: the UI tests on the newest iOS 26 and iOS 27 simulators. Launch screenshots are uploaded as an artifact kept for 7 days.
- On demand: the UI tests on any simulator the runners have.

```sh
gh workflow run ci.yml -f device="iPhone 17 Pro" -f ios=27.2
gh run watch
```

`ios` takes a major version (`26`) or an exact one (`26.5`). Leave it out to run both defaults. iOS 26 runs on the `macos-26` runner and iOS 27 on `xcode-27`. If the runner doesn't have that device and version, the run fails and lists the iOS simulators it does have.

The repository is private, so CI draws on the account's included Actions minutes (about 190 macOS minutes a month on GitHub Free). That's why pushes skip the UI tests.

## Signing and your Apple Developer account

Simulator builds work without an account. For device builds, WeatherKit and StoreKit sandbox testing, copy the example config and fill in your values:

```sh
cp Config/Local.xcconfig.example Config/Local.xcconfig
```

`Config/Local.xcconfig` sets `BUNDLE_ID_PREFIX` and `DEVELOPMENT_TEAM`. It's gitignored, so personal identifiers stay out of the repository. The app group is derived from the prefix as `group.<prefix>.rideornah`.

## Layout

- `RideOrNah/`: the iOS app (SwiftUI). `DesignSystem/AdaptiveSurface.swift` is the one place surfaces get Liquid Glass.
- `RideOrNahUITests/`: UI tests.
- `Packages/RideOrNahKit/`: business logic with no UI framework dependencies, tested with Swift Testing.
- `Config/`: xcconfig files. `scripts/`: helpers used by the Makefile and CI. `.github/workflows/`: CI.
