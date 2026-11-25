# Tasks

## 1. Repository and tooling

- [x] 1.1 Add `.gitignore` covering `*.xcodeproj` (generated), `xcuserdata/`, `DerivedData/`, `.build/`, `.swiftpm/`, `Config/Local.xcconfig` and `.DS_Store`. Verify `git status` shows no build products after task 3.2's build.
- [x] 1.2 Create the `RideOrNah iOS 26` and `RideOrNah iOS 27` simulators from the installed iOS 26.x and 27.x runtimes with `make simulators`. Verify `xcrun simctl list devices` lists both.
- [x] 1.3 Add a `Makefile` with `project`, `build`, `test`, `test-kit` and `audit` targets. `project` fails with a clear message if `xcodegen` is missing. Verify `make project` with XcodeGen temporarily off the PATH prints that message.

## 2. Shared package

- [x] 2.1 Create `Packages/RideOrNahKit/Package.swift` (Swift 6 tools, platforms iOS 26 / watchOS 26 / macOS 26, no dependencies) with a `SharedContainer` library target and a `SharedContainerTests` test target. Verify `make test-kit` builds it.
- [x] 2.2 Implement `SharedContainer` to return the app-group container URL, falling back to a per-process temporary directory when the group container is unavailable (tests, previews, simulator without entitlement). Verify Swift Testing cases cover both paths and `make test-kit` passes.

## 3. App target

- [x] 3.1 Add `Config/Base.xcconfig` (bundle ID prefix and team placeholders, app group ID, Swift 6, iOS 26.0 deployment target, optional `#include? "Local.xcconfig"`) and `Config/Local.xcconfig.example`. Verify `make project` succeeds with no `Local.xcconfig` present.
- [x] 3.2 Write `project.yml` defining the `RideOrNah` iOS app target (default MainActor isolation, app-group entitlement, depends on `RideOrNahKit`) and the `RideOrNahUITests` target. Verify `make project` generates `RideOrNah.xcodeproj` and `make build` succeeds for the iOS Simulator.
- [x] 3.3 Add `RideOrNah/PrivacyInfo.xcprivacy` with tracking off, no tracking domains, no collected data, and UserDefaults reasons `CA92.1` and `1C8F.1`. Verify `plutil -p` on the built app bundle's copy shows those values.
- [x] 3.4 Add `RideOrNah/DesignSystem/AdaptiveSurface.swift` with `adaptiveSurface(in:)`, which applies Liquid Glass with no availability check. Verify with a SwiftUI preview, and with screenshots on iOS 26.x and the latest iOS (local or from CI) showing glass on both.
- [x] 3.5 Add a placeholder root view showing the app name on an adaptive surface, following light/dark mode and Dynamic Type. Verify on the latest iOS simulator at the largest accessibility text size (nothing truncated) and after toggling dark mode while it's running (updates without a relaunch).

## 4. Tests, audit and docs

- [x] 4.1 Write a UI smoke test that launches the app, asserts the placeholder title exists and has an accessibility label, and attaches a screenshot that is always kept. Verify `make test` passes on the iOS 26.x and latest iOS simulators.
- [x] 4.2 Implement `make audit` to fail when `swift package show-dependencies` or `project.yml` lists any remote package. Verify it passes now and fails after temporarily adding a dummy remote package.
- [x] 4.3 Write `README.md` covering requirements (Xcode 27.1+, iOS 26 and 27 simulator runtimes), `make project`, `make test` (including `DESTINATION`), `make test-kit`, `Local.xcconfig` setup and running CI on a chosen device. Verify by following it from a fresh clone into a temporary directory, through to a passing `make test-kit`.

## 5. Continuous integration

- [x] 5.1 Let `make test` take a `DESTINATION` override that runs the UI tests on that one simulator instead of the two named ones, and write the result bundle under `build/` (gitignored). Verify `make test DESTINATION='platform=iOS Simulator,name=RideOrNah iOS 27'` runs only there and leaves a result bundle in `build/`.
- [x] 5.2 Add `.github/workflows/ci.yml` with a `checks` job on `xcode-27` that installs XcodeGen and runs `make audit`, `make test-kit` and `make build` on every push to `main` and every pull request. Cancel superseded runs on the same branch and give every job a timeout. Verify a push to `main` shows a passing `checks` run.
- [x] 5.3 Add a `ui-tests` job that runs on pull requests and on `workflow_dispatch`: by default on the newest iOS 26.x simulator (`macos-26`) and the newest iOS 27.x simulator (`xcode-27`); with `device` and `ios` inputs, on that one simulator, with the runner and Xcode chosen from the iOS version. Verify a manual run with `-f device="iPhone 17"` and an iOS 26.x version passes, and one with an iOS version the runners lack fails and lists the available simulators.
- [x] 5.4 Export the UI tests' screenshots from the result bundle and upload them as an artifact kept 7 days. Verify the artifact from a 5.3 run holds the launch screenshot for each simulator.
