# Tasks

## 1. Repository and tooling

- [ ] 1.1 Add `.gitignore` covering `*.xcodeproj` (generated), `xcuserdata/`, `DerivedData/`, `.build/`, `.swiftpm/`, `Config/Local.xcconfig` and `.DS_Store`. Verify `git status` shows no build products after task 3.2's build.
- [ ] 1.2 Install the latest iOS 18.x simulator runtime with `xcodebuild -downloadPlatform iOS -buildVersion <18.x>`. Verify `xcrun simctl list runtimes` lists it.
- [ ] 1.3 Add a `Makefile` with `project`, `build`, `test`, `test-kit` and `audit` targets. `project` fails with a clear message if `xcodegen` is missing. Verify `make project` with XcodeGen temporarily off the PATH prints that message.

## 2. Shared package

- [ ] 2.1 Create `Packages/RideOrNahKit/Package.swift` (Swift 6 tools, platforms iOS 18 / watchOS 11 / macOS 15, no dependencies) with a `SharedContainer` library target and a `SharedContainerTests` test target. Verify `make test-kit` builds it.
- [ ] 2.2 Implement `SharedContainer` to return the app-group container URL, falling back to a per-process temporary directory when the group container is unavailable (tests, previews, simulator without entitlement). Verify Swift Testing cases cover both paths and `make test-kit` passes.

## 3. App target

- [ ] 3.1 Add `Config/Base.xcconfig` (bundle ID prefix and team placeholders, app group ID, Swift 6, iOS 18.0 deployment target, optional `#include? "Local.xcconfig"`) and `Config/Local.xcconfig.example`. Verify `make project` succeeds with no `Local.xcconfig` present.
- [ ] 3.2 Write `project.yml` defining the `RideOrNah` iOS app target (default MainActor isolation, app-group entitlement, depends on `RideOrNahKit`) and the `RideOrNahUITests` target. Verify `make project` generates `RideOrNah.xcodeproj` and `make build` succeeds for the iOS Simulator.
- [ ] 3.3 Add `RideOrNah/PrivacyInfo.xcprivacy` with tracking off, no tracking domains, no collected data, and UserDefaults reasons `CA92.1` and `1C8F.1`. Verify `plutil -p` on the built app bundle's copy shows those values.
- [ ] 3.4 Add `RideOrNah/DesignSystem/AdaptiveSurface.swift` with `adaptiveSurface(in:)` (glass on iOS 26+, regular material before). Verify with a SwiftUI preview, and with simulator screenshots on iOS 18.x (material) and the latest iOS (glass).
- [ ] 3.5 Add a placeholder root view showing the app name on an adaptive surface, following light/dark mode and Dynamic Type. Verify on the latest iOS simulator at the largest accessibility text size (nothing truncated) and after toggling dark mode while it's running (updates without a relaunch).

## 4. Tests, audit and docs

- [ ] 4.1 Write a UI smoke test that launches the app and asserts the placeholder title exists and has an accessibility label. Verify `make test` passes on the iOS 18.x and latest iOS simulators.
- [ ] 4.2 Implement `make audit` to fail when `swift package show-dependencies` or `project.yml` lists any remote package. Verify it passes now and fails after temporarily adding a dummy remote package.
- [ ] 4.3 Write `README.md` covering requirements, `make project`, `make test`, `make test-kit` and `Local.xcconfig` setup. Verify by following it from a fresh clone into a temporary directory, through to a passing `make test-kit`.
