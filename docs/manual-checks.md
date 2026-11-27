# Manual checks

Spec scenarios that no automated test can reach, and how to check them by hand. `make spec-coverage` accepts a scenario listed here in place of a linked test, and prints the list on every run so it stays visible.

Only list a scenario here when neither a Mac nor a simulator can check it: App Store behavior, real devices, or things a UI test can't observe. Each `## ` heading must be `<capability>: <scenario name>` exactly as the spec writes it. When a scenario gains a test, delete its entry here.

## app-platform: Any supported OS

- **When:** on every pull request that changes UI.
- **How:** open the pull request's CI run, download the iOS 26 and iOS 27 screenshot artifacts, and confirm surfaces and system controls show Liquid Glass.
- **Why not a test:** a UI test can see that an element exists, but not which material it's drawn with.

## app-platform: Network destinations

- **When:** before each App Store submission.
- **How:** run a Release build on a real iPhone through every feature while recording traffic with Instruments' Network template, and confirm every host is Apple-operated (WeatherKit, App Store and StoreKit, Apple Maps, iCloud). Legal links must open in Safari, not inside the app.
- **Why not a test:** it needs a real device, signed services and every feature exercised end to end.

## app-platform: Privacy label

- **When:** before each App Store submission.
- **How:** in App Store Connect → App Privacy, confirm the answers are "Data Not Collected" and that the app doesn't track. The privacy manifest's contents are tested by `RideOrNahTests/AppBundleTests.swift`.
- **Why not a test:** the label lives in App Store Connect, not in the app.

## widgets: Attribution review

- **When:** before each App Store submission.
- **How:** read Apple's current WeatherKit attribution guidelines (developer.apple.com/weatherkit/get-started). For each widget family (small, medium, circular, rectangular, inline), confirm either that it shows the Apple Weather mark, or that tapping it opens a screen that shows the mark and the "Weather data sources" link. Today and Day detail show both, and `WidgetLinkTests` checks the tap. Record the date and guideline version in the release notes.
- **Why not a test:** the guidelines are Apple's document and change over time. A person has to read them against the widgets.

## app-release: Next build number

- **When:** after each upload, from the Mac or from CI.
- **How:** in App Store Connect → TestFlight → iOS Builds, or with `asc builds list --app <APP_ID> --output table`, confirm the new build's number is one above the previous highest, whichever machine uploaded it.
- **Why not a test:** the number comes from App Store Connect at upload time.

## app-release: Store products match PlanFetch

- **When:** after creating or changing the subscriptions, and before each App Store submission.
- **How:** run `make asc-subscriptions` and confirm both apps show the same periods and US prices ($19.99 a year, $2.99 a month). Then, on each app's Subscriptions page in App Store Connect, confirm both plans have a one-week free trial in every territory, Family Sharing off, and availability in all territories.
- **Why not a test:** the products live in App Store Connect, not in the app.

## app-release: Upload to TestFlight

- **When:** the first upload from each machine (the Mac, CI), and after changing `scripts/testflight.sh`, `Config/ExportOptions.plist` or the workflow.
- **How:** run `make testflight` or start the TestFlight workflow from `main`. Confirm it ends with "is in TestFlight", and that App Store Connect → TestFlight shows the build as ready to test in "Ride or Nah Team".
- **Why not a test:** it signs and uploads a real build to App Store Connect.

## app-release: Trial on a TestFlight build

- **When:** on the first TestFlight build, and before each App Store submission.
- **How:** follow the device check under "Subscriptions" in `docs/app-store-connect.md`: install the TestFlight build with a Sandbox Apple Account, start the free trial from the paywall, and confirm Today unlocks.
- **Why not a test:** it needs a real device, a sandbox account and App Store Connect's products.

# Other release checks

Checks that back a requirement without being a scenario of their own. `make spec-coverage` doesn't read these.

### Watch delivery between paired devices

- **When:** before each App Store submission, and after changing `WatchSender` or `WatchReceiver`.
- **How:** with a real iPhone and a paired Apple Watch running the release candidate:
  1. Open the iPhone app and wait for the forecast.
  2. Open the watch app, and confirm it shows the same verdict, windows and reasons as Today.
  3. Add the rectangular complication and confirm it matches.
  4. Lock the watch or lower the wrist, and confirm the place name hides.
  5. Leave the iPhone's background refresh to run overnight, and confirm the watch shows the morning's results.
- **Why not a test:** WatchConnectivity doesn't deliver application contexts between simulators reliably, so tests cover the sender (`WatchSenderTests`) and the receiver (`WatchStoreTests`) separately.
