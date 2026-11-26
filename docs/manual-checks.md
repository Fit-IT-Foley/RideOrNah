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

## app-platform: Color-independent state

- **When:** until the first screen that shows state with color. `today-and-outlook`, with its verdict, will be the first.
- **How:** nothing to check yet, because the placeholder screen shows no color-coded state. The change that adds the first one must add a UI test that reads the state's accessibility label, link it to this scenario, and delete this entry.
- **Why not a test:** there's no color-coded state to test yet.
