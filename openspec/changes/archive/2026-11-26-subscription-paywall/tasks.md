# Tasks

Every test that proves a scenario links to it with `// Scenario: subscription: <scenario name>` on the line above it.

## 1. Access and wording (package)

- [x] 1.1 Add the `Entitlements` target with `SubscriptionFact`, `Access` and `AccessPolicy`. Verify tests linked to "Offline subscriber", "Billing grace period" and "Unverified transaction" pass.
- [x] 1.2 Add `PlanOffer` and `PaywallPresenter` to `Presentation`. Verify tests linked to "Localized pricing", "Not eligible for a trial" and "Required disclosures" pass.
- [x] 1.3 Add the access mirror to `SharedContainer`, written on every change and read back by widgets and the watch later. Verify a package test round-trips it.

## 2. App

- [x] 2.1 Add `StoreKit/RideOrNah.storekit` with the monthly and annual plans in one group, each with a 1-week free trial, set it on the Run scheme in `project.yml`, and bundle it with the app-hosted tests.
- [x] 2.2 Implement `AccessController`: products, status, `Transaction.updates`, purchase, restore, and the `-accessStub` debug override. Verify app-hosted `SKTestSession` tests linked to "Purchase on another device", "Refund" and "Restore on a new phone" pass.
- [x] 2.3 Gate weather and notifications on access: no refresh, pending ride notifications removed while locked, and a refresh and rebuild when access returns. Verify app-hosted tests linked to "Editing without access", "Trial ends without purchase" and "Resubscribing" pass.
- [x] 2.4 Build the paywall, the locked Today and Week states, and the Subscription section in Settings, in the design-system style, with Terms and Privacy opening in Safari. Pass `-accessStub active` in the existing UI tests. Verify UI tests linked to "After setup" and "Dismissed paywall" pass.
- [x] 2.5 Write `docs/privacy-policy.md`, and add the before-submission sandbox purchase check on a device to `docs/app-store-connect.md`. Running that check needs the Developer Program.

## 3. Integration

- [x] 3.1 Verify `make spec-coverage CHANGE=subscription-paywall` passes, and that `make test` and `make test-release` pass on both simulators.
