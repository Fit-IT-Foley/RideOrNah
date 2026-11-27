# Tasks

Every test that proves a scenario links to it with `// Scenario: app-release: <scenario name>` on the line above it. Scenarios only App Store Connect or a real device can show go in `docs/manual-checks.md`.

## 1. Identity and build settings

- [x] 1.1 Set `APP_BUNDLE_ID`, `DEVELOPMENT_TEAM`, `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in `Config/Base.xcconfig`, and derive the app group and every target's bundle ID, version and build number from them in `project.yml`. Retire `BUNDLE_ID_PREFIX`, and update `Local.xcconfig.example` and the README's bundle ID mention. Verify app-hosted tests linked to "Bundle identifiers" and "Matching versions" pass.
- [x] 1.2 Set the app's Home Screen label to "Ride or Nah", and declare `ITSAppUsesNonExemptEncryption` false in all four Info.plists. Verify app-hosted tests linked to "Home Screen name" and "Encryption declaration" pass.

- [x] 1.3 Add the app icon (canvas option E) to the app and the watch app: `scripts/render-app-icon.swift` and `make app-icon` write a 1024 × 1024 opaque PNG into each target's `AppIcon` asset catalog. Note it in `docs/design-system.md`. Verify an app-hosted test linked to "App icons" passes.

## 2. Local prices

- [x] 2.1 Change the prices in `StoreKit/RideOrNah.storekit` and `StubStore.offers` to $19.99 a year and $2.99 a month, keeping the one-week trial, and update the tests that read them. Verify the paywall UI test, linked to "Local prices", passes. On a simulator where StoreKit Testing works, `StoreKitIntegrationTests` should pass too.

## 3. Release tooling

- [x] 3.1 Add `Config/ExportOptions.plist`, `scripts/testflight.sh` and `make testflight`. The script finds the app, numbers the build, archives, exports, uploads, waits for processing and adds the build to the internal group, using `xcodebuild` authentication flags when CI's key variables are set. Verify that with no app record it stops with a message naming the missing record, and that `bash -n scripts/testflight.sh` passes.
- [x] 3.2 Add `.github/workflows/testflight.yml`: started manually and only from `main`, one run at a time, on the `xcode-27` runner, with the key decoded to a temporary file and removed afterwards. Verify the YAML parses, and that `ci.yml`'s pull-request jobs are unchanged.
- [x] 3.3 Document the release in `docs/app-store-connect.md`. Replace "Next: TestFlight" with how to upload from the Mac and from CI, give the products table its prices, and list the owner-only steps (app record, CI secrets). Add `make testflight` to the README. Add the four manual checks ("Next build number", "Store products match PlanFetch", "Upload to TestFlight" and "Trial on a TestFlight build") to `docs/manual-checks.md`.

## 4. App Store Connect (needs Developer Program)

- [x] 4.1 Archive once with automatic signing, so Xcode registers the four App IDs with App Groups and WeatherKit, and the app group (needs Developer Program). Verify `make asc-bundle-ids` lists all four IDs.
- [x] 4.2 The owner creates the app record: "Ride or Nah", `com.rideornah.RideOrNah`, SKU `rideornah-ios`, English (U.S.) (needs Developer Program, owner only). Verify `make asc-apps` lists it.
- [x] 4.3 Create the subscription group and both products with localizations, US prices equalized everywhere, availability in all territories, the one-week free trial in every territory, Family Sharing off, and the review screenshot (needs Developer Program). Verify the "Store products match PlanFetch" manual check with its read-only comparison.
- [x] 4.4 Create the internal TestFlight group "Ride or Nah Team" with the owner in it (needs Developer Program). Verify `asc testflight groups list --app <id> --internal` shows it with the owner.
- [ ] 4.5 Run `make testflight` from the owner's Mac (needs Developer Program). Verify the "Upload to TestFlight" manual check: build 1 of 1.0 is processed and in the internal group.

## 5. CI uploads

- [ ] 5.1 The owner creates the "RideOrNah CI" API key and sets the three repository secrets (owner only). Verify `gh secret list` shows the three names.
- [ ] 5.2 Run the TestFlight workflow from `main` (needs Developer Program). Verify the "Next build number" manual check: the workflow's build is numbered one above the Mac's, and it's processed and in the internal group. If cloud signing refuses the CI key, stop and bring the options from design.md's risks to the owner.

## 6. Devices

- [ ] 6.1 Install the TestFlight build on an iPhone and its paired Apple Watch (needs Developer Program). Verify the "Trial on a TestFlight build" manual check, and that live WeatherKit verdicts appear.

## 7. Integration

- [ ] 7.1 Verify `make spec-coverage CHANGE=testflight-release` passes, and that `make test` and `make test-release` pass on all simulators with the real identity.
