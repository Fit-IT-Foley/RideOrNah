# Spec Delta

## Purpose

Defines how Ride or Nah is identified, versioned and sold in App Store Connect, and how its builds reach TestFlight, so every build that reaches a real device is signed, numbered and configured the same way.

## ADDED Requirements

### Requirement: App identity
The iPhone app SHALL use the bundle ID `com.rideornah.RideOrNah`. Its widget extension SHALL use `com.rideornah.RideOrNah.Widgets`, the watch app `com.rideornah.RideOrNah.watchkitapp`, and the watch complications `com.rideornah.RideOrNah.watchkitapp.Widgets`. All four SHALL share the app group `group.com.rideornah.RideOrNah`, and the watch app SHALL name the iPhone app as its companion. The Home Screen label and the App Store name SHALL both be "Ride or Nah".

#### Scenario: Bundle identifiers
- **WHEN** the app is built
- **THEN** the app, widget extension, watch app and complications carry those four bundle IDs, all declare the same app group, and the watch app's companion is `com.rideornah.RideOrNah`

#### Scenario: Home Screen name
- **WHEN** the app is installed
- **THEN** its Home Screen label reads "Ride or Nah"

### Requirement: App icons
The iPhone app and the watch app SHALL each include the app icon chosen on the design canvas, in every size the App Store requires.

#### Scenario: App icons
- **WHEN** the app is built
- **THEN** the iPhone app and the watch app each name their app icon and carry it in their bundle

### Requirement: Versions and build numbers
The app, widget extension, watch app and complications SHALL carry the same version and the same build number. Each build uploaded to App Store Connect SHALL have a build number higher than every earlier upload of that version, so no upload is rejected as a duplicate.

#### Scenario: Matching versions
- **WHEN** the app is built
- **THEN** all four bundles report the same version and build number

#### Scenario: Next build number
- **WHEN** builds 1 to 4 of version 1.0 have already been uploaded and a new upload starts
- **THEN** the new build is numbered 5

### Requirement: Export compliance
Every bundle SHALL declare that the app uses no encryption beyond what Apple's operating systems provide, so App Store Connect doesn't hold builds for the export-compliance question.

#### Scenario: Encryption declaration
- **WHEN** the app is built
- **THEN** the app, widget extension, watch app and complications each declare that they use no non-exempt encryption

### Requirement: Subscription products in the App Store
App Store Connect SHALL offer exactly two auto-renewable subscriptions for the app, in one subscription group, with the same pricing as the owner's PlanFetch app:
- `rideornah.annual` at a US price of $19.99 a year, ranked above the monthly plan.
- `rideornah.monthly` at a US price of $2.99 a month.

Other territories SHALL use the App Store's equalized prices for those US prices. Both SHALL offer new subscribers a one-week free trial, SHALL have Family Sharing turned off, and SHALL be available in every territory the app is sold in. Debug builds that don't reach the App Store SHALL show the same US prices and trial, so tests and screenshots match what riders see.

#### Scenario: Store products match PlanFetch
- **WHEN** the owner compares the app's subscriptions in App Store Connect with PlanFetch's
- **THEN** the periods, US prices, free-trial length, Family Sharing and territory availability are the same

#### Scenario: Local prices
- **WHEN** a debug build shows the paywall without the App Store
- **THEN** the annual plan reads "Free for 1 week, then $19.99 a year" and the monthly plan is $2.99 a month

### Requirement: TestFlight uploads
Builds SHALL reach TestFlight only when the owner starts an upload, from their Mac or from a manually started CI workflow, and never from pull requests or pushes. Each upload SHALL be a Release build signed for App Store distribution. Once App Store Connect has processed it, it SHALL be available to the app's internal TestFlight group without further steps. Uploads from CI SHALL authenticate with an App Store Connect API key stored as repository secrets, and SHALL NEVER print the key.

#### Scenario: Upload to TestFlight
- **WHEN** the owner starts an upload from `main`
- **THEN** a Release build with the next build number is processed and appears in TestFlight for the internal group

#### Scenario: Trial on a TestFlight build
- **WHEN** a tester signed in with a Sandbox Apple Account installs a TestFlight build and starts the free trial from the paywall
- **THEN** the purchase completes and Today unlocks
