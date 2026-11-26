# Proposal

## Why

RideOrNah is a subscription product with no server. Purchases, trials and access checks have to run entirely through StoreKit 2 on the device. The paywall has to meet App Store rules on the first submission.

## What Changes

- Offer monthly and annual auto-renewable subscriptions in one subscription group, each with a free-trial introductory offer for eligible riders. The trial is intended to be 7 days, and prices and trial length are set in App Store Connect.
- Show the paywall after first-run setup, and again whenever access is inactive and the rider reaches a feature that needs it.
- Gate verdicts, the outlook, notifications, calendar suggestions, widget content and watch content. Setup, settings, profile editing, the paywall and legal pages stay open.
- Check access on the device from StoreKit's signed transactions, offline included, and honor billing grace periods.
- Handle renewals, expirations, refunds and revocations as they happen. When access ends, stop notifications and lock widgets and the watch, keeping every preference.
- Add restore purchases, manage subscription and offer-code redemption.
- Non-goals: server receipt validation, accounts, lifetime purchases, and paywall A/B tests.

## Capabilities

### New Capabilities
- `subscription`: products, trial, paywall content and placement, access rules, and the lifecycle effects of gaining and losing access.

### Modified Capabilities
- None.

## Impact

- New `Entitlements` target in `RideOrNahKit` (access-state logic, testable with StoreKit Testing), paywall screens, and a `.storekit` configuration file for local testing.
- Privacy: none new. StoreKit is an Apple service and we receive no personal data. The Terms of Use and Privacy Policy links open in Safari, outside the app, so the app itself never contacts a non-Apple host.
- WeatherKit requests: none. Lapsed riders make no weather requests, which keeps costs tied to paying riders.
- Requires the Apple Developer Program, Paid Applications agreement, subscription products in App Store Connect, and hosted Privacy Policy and Terms pages. A free static host such as GitHub Pages keeps the no-backend promise. The products can be created and checked with the `asc` CLI (`docs/app-store-connect.md`), and the App Manager key's role covers subscriptions.
- Open business decisions, none of which change code: prices, final trial length, and whether Family Sharing is on.
