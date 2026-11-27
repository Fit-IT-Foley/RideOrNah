# Proposal

## Why

All ten v1 changes are built and pass on simulators, but nobody can install Ride or Nah on a real iPhone or Apple Watch yet. TestFlight is how the owner and testers try it on real devices, with real WeatherKit and sandbox subscriptions, before an App Store submission. Getting there needs the app's real identity in App Store Connect, its subscription products, signing, and a repeatable way to upload builds.

## What Changes

- **Real identity:**
  - Bundle IDs `com.rideornah.RideOrNah` (app), `.Widgets` (widgets), `.watchkitapp` (watch app) and `.watchkitapp.Widgets` (complications), under team WTF332KZJ6.
  - App group `group.com.rideornah.RideOrNah`.
  - App Store name "Ride or Nah". The Home Screen label changes from "RideOrNah" to "Ride or Nah".
- **App Store Connect setup:**
  - The app record, created by the owner, because Apple only allows that on the website or through a signed-in web session.
  - Two subscriptions in one group, matching PlanFetch's pricing: `rideornah.annual` at $19.99 a year and `rideornah.monthly` at $2.99 a month. Both have a one-week free trial, Family Sharing is off, and they're sold in every territory.
  - An internal TestFlight group for the owner.
- **App icon:** the iPhone and Watch apps get the icon chosen on the design canvas, "E · Tachometer". The App Store rejects any build without one.
- **Local mirrors:** the local StoreKit configuration and the UI tests' stand-in store use the same prices, so screenshots and tests look like the real thing. The app still reads real prices from the App Store at runtime.
- **Builds:**
  - Version 1.0, with each upload's build number taken from App Store Connect, so uploads never collide.
  - Every bundle declares that it uses no non-exempt encryption, so builds don't wait on the export-compliance question.
- **Uploads:**
  - `make testflight` archives a Release build, signs it with Xcode's automatic signing and a cloud-managed distribution certificate, uploads it, waits for processing, and gives it to the internal group.
  - The first upload runs from the owner's Mac.
  - A manually started GitHub Actions workflow does the same on later runs. It uses an App Store Connect API key the owner stores as repository secrets. Pull requests never upload.
- **Non-goals:** App Store submission, screenshots and metadata, external (public) TestFlight testing, which needs Beta App Review, and hosting the privacy policy.

## Capabilities

### New Capabilities
- `app-release`: the app's identity (bundle IDs, app group, names), export compliance, versioning and build numbers, the App Store subscription products, and how builds reach TestFlight.

### Modified Capabilities
- None. The `subscription` requirements already say prices come from the App Store at runtime; this change only sets what those prices are.

## Impact

- **Build settings:**
  - `Config/Base.xcconfig` gets the real bundle ID, team, version and build number.
  - `project.yml` derives every target's bundle ID, app group, version and build number from them.
  - The Info.plists gain `ITSAppUsesNonExemptEncryption`.
- **App icon:** asset catalogs for the app and the watch app, and `scripts/render-app-icon.swift` with `make app-icon`, which draws the icon.
- **Release tooling:** a new `make testflight` target and `scripts/testflight.sh`, a new `.github/workflows/testflight.yml`, and updates to `docs/app-store-connect.md` and the README.
- **Tests:** `RideOrNahTests/AppBundleTests.swift` gains identity and compliance checks. Price assertions move to $19.99 and $2.99.
- **App Store Connect and the Developer portal:**
  - New App IDs with the App Groups and WeatherKit capabilities.
  - The app group, the app record, the subscription group and products, and an internal TestFlight group.
  - A cloud-managed Apple Distribution certificate.
- **Owner steps:**
  - Create the app record.
  - Accept the Paid Applications agreement, which subscriptions need, though TestFlight itself doesn't.
  - Set the CI secrets.
- **Privacy:** no new permissions, and no new data leaves the device. TestFlight's own crash and feedback reports come from Apple's TestFlight app, not from Ride or Nah's code, and don't change the "Data Not Collected" label.
- **WeatherKit requests:** none added by this change. TestFlight builds are the first to use live WeatherKit on real devices, so testers' requests start counting toward the monthly allowance, within the same per-device budget.
