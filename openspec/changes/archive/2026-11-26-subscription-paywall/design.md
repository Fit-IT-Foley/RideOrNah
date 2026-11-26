# Design

## Context

Everything a rider sees comes from `ForecastController`, and `NotificationCoordinator` schedules the morning notification. Neither checks access yet. The design canvas doesn't draw a paywall, so it uses the tokens and components in `docs/design-system.md`. See proposal.md for motivation and the spec for behavior.

## Goals / Non-Goals

**Goals:**
- Access rules and paywall wording come from pure code in `RideOrNahKit`, tested on the Mac without StoreKit.
- StoreKit lives in one app type, so the rest of the app only reads an `Access` value.
- UI tests run without StoreKit or a sandbox account.

**Non-Goals:**
- Locking widgets and the watch. They read the access mirror described below, and `widgets` and `watch-app` draw their locked states.
- Prices, the final trial length and Family Sharing. Those are set in App Store Connect.

## Decisions

### `Entitlements` target: access from plain facts
`SubscriptionFact` is what the app reads from StoreKit for each plan:
- the product ID and plan (monthly or annual),
- whether the transaction verified,
- its renewal state: subscribed, in grace period, in billing retry, expired or revoked,
- whether it's an introductory (trial) period, whether it will renew, and its expiry date.

`AccessPolicy.access(from:)` returns `Access`: `.active(plan:, inTrial:, renews:)` or `.inactive`. `AccessPolicy.ends(from:)` returns the expiry when the subscription won't renew (a cancelled trial), so nothing is scheduled past it.
- A fact grants access only when it verified and its state is subscribed or in grace period.
- Billing retry without grace, expired and revoked never grant it.
- When several facts grant it, the annual plan wins, so the paywall's "current plan" is stable.

StoreKit keeps the latest verified status on the device, so the same facts are available offline. The check never needs a connection.

### `PaywallPresenter` in `Presentation`
`PlanOffer` carries what StoreKit reports for a plan: its display price, its period, and the free-trial length if the rider is eligible. Prices and currency always come from StoreKit's `displayPrice`, never from code.

`PaywallPresenter` turns offers into each plan's title, price line and the disclosure under the button:
- With a trial: "Free for 1 week, then $4.99 a month. Renews automatically until you cancel."
- Without one: "$4.99 a month. Renews automatically until you cancel." with no trial wording anywhere.
- The annual plan also shows its monthly equivalent, worked out from the display price's own currency and rounding.

### `AccessController` in the app
`AccessController` is `@Observable` and runs on the main actor.
- **Reading access:** it loads the two products, reads `Product.SubscriptionInfo.status(for:)` for the group, maps each status to a `SubscriptionFact`, and publishes `access` and `offers`.
- **Live updates:** it listens to `Transaction.updates` from launch, finishes each transaction and re-reads status. Renewals, refunds, revocations and purchases on other devices therefore land without a relaunch.
- **Actions:** `purchase(_:)`, `restore()`, the manage-subscriptions sheet and the offer-code sheet. `restore()` calls `AppStore.sync()` through a replaceable closure, because the real call can show an Apple Account sign-in prompt, even under StoreKit Testing.
- **Debug override:** in debug builds `-accessStub active|inactive` replaces StoreKit with a fixed access value and stub offers, so UI tests never meet StoreKit. Existing UI tests pass `-accessStub active`.

### What locks, and how
- **Weather:** `ForecastController.refresh` makes no request without access, and Today and Week show a locked state instead of the verdict.
- **Notifications:** `NotificationCoordinator.rebuild` removes every pending ride notification without access, and rebuilds as usual when access returns. While a cancelled subscription runs out, it schedules nothing past its end. The background refresh checks access first, so a lapsed subscription stops notifications even if the app isn't opened.
- **Gaining or losing access** triggers a refresh and a rebuild. Preferences are never touched. `AccessController.connect(forecast:notifications:)` holds this wiring, so the app and the tests share it.
- **At launch:** before StoreKit answers, the app starts locked or unlocked from the access mirror. A lapsed rider makes no weather request, and a subscriber doesn't see a locked screen flash by.
- **Access mirror:** `SharedContainer` gets an access mirror (active or not, and when it was checked), written on every change. Widgets and the watch read it later.

### Screens
The paywall is a full-screen cover in the design-system style:
- the wordmark and a display headline with the accent dot,
- what's included as a short list,
- two plan cards, annual first and pre-selected,
- a primary pill that reads "Start free trial" or "Subscribe",
- the disclosure,
- then Restore Purchases, Redeem code, and Terms of Use and Privacy Policy links. Both links open in Safari via `Link`.

Placement:
- It shows when first-run setup finishes without access, and from the locked Today and Week screens ("See plans").
- Closing it leaves the rider on the locked screen. Settings stays reachable from the gear.
- The Alerts tab stays editable without access and says notifications start once the rider subscribes.

Settings gains a Subscription section: the current plan, Manage subscription (system sheet), Restore Purchases and Redeem code.

### Products and local testing
- **Products:** `rideornah.monthly` and `rideornah.annual` in one group, each with a 1-week free-trial introductory offer.
- **Local testing:** `StoreKit/RideOrNah.storekit` holds them for testing. It sits outside the app's sources, so it never ships. It's set on the Run scheme, and app-hosted tests drive it with `SKTestSession` (purchase outside the app, refund, expire). Its prices are placeholders; App Store Connect sets the real ones.
- **Legal links:** Terms of Use points to Apple's standard licensed application end user license agreement. The Privacy Policy is `docs/privacy-policy.md`, served from the repository's GitHub Pages site. The URL lives in one `LegalLinks` constant.

## Risks / Trade-offs

- [StoreKit Testing loads no products and refuses purchases (`.notEntitled`) on the iOS 26 simulator] → The `SKTestSession` tests run on iOS 27 and later, and CI runs them there. The access-gating tests don't use StoreKit and run on both. Trial eligibility isn't asserted, because StoreKit Testing reports riders as ineligible even when the purchase gets the trial. The package tests cover both wordings.
- [`SKTestSession` on hosted CI simulators can be slow] → Each test only waits on its own transaction, using its own session and a fresh `clearTransactions()`.
- [App Review rejects a paywall missing a disclosure] → The disclosure text is tested, and `docs/manual-checks.md` gets a sandbox purchase check on a device before submission.
- [The privacy policy URL isn't live until GitHub Pages is turned on] → The owner turns it on. Until then, the link is the one manual check left open.

## Open Questions

- Prices, final trial length and Family Sharing (App Store Connect, no code change).
