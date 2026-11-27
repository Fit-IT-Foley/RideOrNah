# Design

## Context

- **Placeholder identity:** the project builds with `com.example` bundle IDs, an empty team and hard-coded versions (`1.0`, build `1`) in four generated Info.plists. Simulators accept that, but devices, App Store Connect and TestFlight don't.
- **The team:** WTF332KZJ6, an individual Developer Program membership.
  - Xcode on the owner's Mac is signed in to it. The only signing identity there is an Apple Development certificate.
  - The team's other apps (PlanFetch, Change Proof) had their App IDs registered by Xcode's automatic signing.
- **App Store Connect key:** the `rideornah` profile in `asc` is a working Team API key with the App Manager role (see `docs/app-store-connect.md`).
- **Paid Applications agreement:** PlanFetch already has approved subscriptions, so the agreement is in effect.
- **PlanFetch's pricing, read from App Store Connect:**
  - Annual $19.99 and monthly $2.99, in one group, with Annual ranked first.
  - A one-week free trial on both, in every territory.
  - Family Sharing off.

See proposal.md for why this change exists.

## Goals / Non-Goals

**Goals:**
- **One upload path:** the owner's Mac and CI run the same script. The only difference is how signing authenticates.
- **Identity in one place:** the bundle ID, team, version and build number are set in one place, and every target derives from them.

**Non-Goals:**
- Managing signing certificates or profiles by hand.
- Fastlane or any other release tool beyond `asc` and `xcodebuild`.
- App Store submission.

## Decisions

### Identity in `Config/Base.xcconfig`
- **Settings:** `APP_BUNDLE_ID = com.rideornah.RideOrNah`, `DEVELOPMENT_TEAM = WTF332KZJ6`, `MARKETING_VERSION = 1.0` and `CURRENT_PROJECT_VERSION = 1`.
- **Derived values:** `APP_GROUP_IDENTIFIER = group.$(APP_BUNDLE_ID)`, and every target's bundle ID in `project.yml` is `$(APP_BUNDLE_ID)` plus a suffix. The test bundles get `.Tests`, `.UITests` and `.watchkitapp.UITests`.
- **Info.plists:** each takes `$(MARKETING_VERSION)` and `$(CURRENT_PROJECT_VERSION)`. That way all four bundles always match, and one build setting changes the build number for all of them.
- **Placeholder setting retired:** `BUNDLE_ID_PREFIX` goes away. `Local.xcconfig` stays as the override for anyone building under another team.
- **Why commit the team ID:** it's public in every signed app, so it isn't a secret. Keeping it in `Base.xcconfig` makes CI and fresh clones sign without local setup.
- **Alternative considered:** keep `com.example` in the repo and put the real values only in `Local.xcconfig`. Rejected because CI would then need the values passed in separately, and the identity tests couldn't check the real IDs.

### Names and export compliance in `project.yml`
- **Names:** the app's `CFBundleDisplayName` becomes "Ride or Nah", matching the widgets and watch app.
- **Export compliance:** all four targets get `ITSAppUsesNonExemptEncryption: false`. The app only uses HTTPS through Apple's frameworks, which is exempt.

### App icon: drawn on the canvas, rendered by a script
- **Design:** the canvas board "App icon — wordmark with gauge", option E. The stacked RIDE / *or* / NAH wordmark sits inside tachometer ticks, orange on the Ride side and blue on the Nah side, with a white needle on Ride. The first upload showed it was missing: App Store Connect rejects a build without icons.
- **Rendering:** `scripts/render-app-icon.swift` (`make app-icon`) draws the board's geometry with Core Graphics at 1024 × 1024. It uses the same system fonts the app's `Wordmark` uses: heavy condensed for RIDE and NAH, semibold italic serif for "or". It writes an opaque PNG into `RideOrNah/Assets.xcassets` and `Watch/App/Assets.xcassets` as a single-size `AppIcon`. iOS rounds the corners and watchOS crops to a circle, and everything in the design sits inside that circle.
- **Why a script:** exporting from the canvas would need its Google Fonts installed and would produce a screenshot. The script makes the icon reproducible, and it matches the in-app wordmark.

### Signing: Xcode automatic signing, cloud-managed distribution
- **Archive:** `xcodebuild archive` and `-exportArchive` run with `-allowProvisioningUpdates`.
- **What automatic signing creates on the first archive:**
  - the four App IDs, from the bundle IDs,
  - their App Groups and WeatherKit capabilities, from the entitlements files,
  - the app group,
  - the App Store profiles.
- **Distribution certificate:** the export uses a cloud-managed Apple Distribution certificate, so no `.p12` exists to store, leak or rotate.
- **How it authenticates:**
  - **On the Mac:** through the Apple Account already signed in to Xcode.
  - **In CI:** through an App Store Connect API key, using `-authenticationKeyPath`, `-authenticationKeyID` and `-authenticationKeyIssuerID`.
- **Alternatives considered:**
  - Register IDs first with `asc bundle-ids create`. The App Store Connect API can't create app groups, so Xcode would still be needed.
  - Manual signing with an exported certificate and `asc signing fetch`. That means more secrets and yearly certificate renewals.

### Upload script: `scripts/testflight.sh`, run by `make testflight`
1. **Find the app:** look up its App Store Connect ID by bundle ID (`asc apps list --bundle-id`). If there's no app record, stop and say the owner needs to create it.
2. **Number the build:** get the build number from `asc builds next-build-number` for the marketing version. That gives the "Next build number" scenario without counting anything locally.
3. **Build:** run `make project`, then archive the `RideOrNah` scheme in Release for `generic/platform=iOS`, with that `CURRENT_PROJECT_VERSION`. The watch app and both extensions are embedded.
4. **Export:** use `Config/ExportOptions.plist` (method `app-store-connect`, automatic signing, the team, symbol upload on).
5. **Upload:** `asc builds upload`, then `asc builds wait` until processing finishes, then add the build to the internal group by name.
- **CI mode:** when `ASC_KEY_ID`, `ASC_ISSUER_ID` and a key file path are in the environment, the script adds the `xcodebuild` authentication flags. Otherwise it relies on Xcode's signed-in account and the `asc` keychain profile.
- **Why upload with asc:** `asc` handles the upload and the TestFlight steps in both places. Letting `xcodebuild -exportArchive` upload with `destination: upload` would leave CI needing two different authentication paths.

### CI workflow: `.github/workflows/testflight.yml`
- **When it runs:** only on `workflow_dispatch`, and only from `main`. Its concurrency group allows one upload at a time.
- **Runner:** `xcode-27`, so builds use the newest SDK, the one the local build uses.
- **The key:** read from the secrets `ASC_KEY_ID`, `ASC_ISSUER_ID` and `ASC_PRIVATE_KEY_B64`. The base64 copy is decoded to a file in `$RUNNER_TEMP` with mode 600 and deleted at the end. It's never echoed, and GitHub masks the secret values in logs.
- **Separate from ci.yml:** pull requests and pushes can't start it, and a run gets no secrets unless someone with write access starts it.

### App Store Connect setup
- **App record (the owner):** created on the website or with `asc web apps create`, which signs in with an Apple Account. Values:
  - name "Ride or Nah",
  - bundle ID `com.rideornah.RideOrNah`,
  - SKU `rideornah-ios`,
  - primary language English (U.S.).
- **Subscriptions (scripted with the App Manager key):**
  - A group "Ride or Nah" with an English display name.
  - `rideornah.annual` (level 1, `ONE_YEAR`) and `rideornah.monthly` (level 2, `ONE_MONTH`), with English display names and descriptions.
  - US prices of $19.99 and $2.99, which App Store Connect equalizes for other territories. Available in all territories, including new ones.
  - A `FREE_TRIAL` intro offer of `ONE_WEEK` in every territory, imported like PlanFetch's.
  - Family Sharing off.
  - A paywall screenshot as the review screenshot, so both products reach Ready to Submit and load in the sandbox.
- **TestFlight group:** an internal group, "Ride or Nah Team", containing the owner.

### Local mirrors of the prices
- **What changes:** the prices in `StoreKit/RideOrNah.storekit` and `StubStore.offers`, plus the tests that read them.
- **Debug-only:** the `.storekit` file is used only by the Run scheme and the test bundle, and `StubStore` exists only in debug builds. Release builds still read prices from the App Store.

## Risks / Trade-offs

- **[CI can't create a cloud-managed certificate]** Apple may limit cloud signing through an API key to keys with the Admin role. → First try the CI key with App Manager. If the export fails with a certificate permission error, the owner chooses between an Admin-role key used only for CI, or exporting a regular Apple Distribution certificate as a `.p12` secret.
- **[The App Store name "Ride or Nah" is taken]** → App Store Connect refuses it when the record is created. The owner then picks a variant, such as "Ride or Nah: Moto Weather", and the spec's name changes with it.
- **[Subscriptions don't load in the sandbox]** That can happen while products are missing metadata. → Supply the localizations and the review screenshot when the products are created, and check them on a TestFlight build ("Trial on a TestFlight build").
- **[Changing the app group loses simulator data]** → It only affects simulators and debug installs. Nobody has a real install yet.
- **[`asc` on CI isn't the pinned version]** Homebrew installs whatever version is current. → The script uses only long-standing commands, and the workflow prints `asc --version`.

## Migration Plan

1. Land the identity, mirror and tooling changes through a pull request as usual. Simulator CI doesn't sign with profiles, so it keeps passing.
2. On the owner's Mac:
   - archive once to register the App IDs and app group,
   - the owner creates the app record,
   - script the subscriptions and the internal group,
   - run `make testflight`.
3. The owner adds the CI secrets. Then run the workflow once to confirm a second build uploads with the next number.

**Rollback:** expire a bad build in TestFlight (`asc builds expire`). Identity changes revert through git. Bundle IDs and the app record stay registered, but they cost nothing.
