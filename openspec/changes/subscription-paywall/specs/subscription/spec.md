# Spec Delta

## Purpose

Defines how riders start a free trial and subscribe, how access is checked entirely on the device, which features need access, and what happens when access begins or ends.

## ADDED Requirements

### Requirement: Subscription products
The system SHALL offer a monthly and an annual auto-renewable subscription in a single subscription group. Each SHALL include a free-trial introductory offer for riders App Store considers eligible. Prices, the trial length and the currency SHALL come from the App Store at runtime and SHALL NEVER be hard-coded.

#### Scenario: Localized pricing
- **WHEN** a rider in Germany opens the paywall
- **THEN** both plans show prices in euros as reported by the App Store

#### Scenario: Not eligible for a trial
- **WHEN** a rider has already used the trial
- **THEN** the paywall offers the plans without a trial and doesn't mention one

### Requirement: Paywall content
The paywall SHALL show, for each plan: the price per period, the trial length and what's charged when it ends (if a trial is offered), and that the subscription renews automatically until cancelled. It SHALL show a short list of what's included, a Restore Purchases action, and working links to the Terms of Use and the Privacy Policy.

#### Scenario: Required disclosures
- **WHEN** the paywall is shown to a trial-eligible rider
- **THEN** it shows the trial length, the price after the trial, renewal terms, Restore Purchases, Terms of Use and Privacy Policy

### Requirement: Paywall placement
The system SHALL show the paywall right after first-run setup completes, and whenever a rider without access opens a feature that needs it. Closing the paywall without subscribing SHALL leave the rider in the app with gated content locked.

#### Scenario: After setup
- **WHEN** a new rider finishes first-run setup
- **THEN** the paywall is shown before the Today screen

#### Scenario: Dismissed paywall
- **WHEN** the rider closes the paywall without subscribing
- **THEN** the app shows a locked Today screen that offers to reopen the paywall, and settings remain usable

### Requirement: What needs access
Verdicts, the 7-day outlook, day details, ride notifications, calendar suggestions, widget content and watch content SHALL require access. First-run setup, settings, profile and location editing, the paywall, restore, and the legal and about pages SHALL NOT require access.

#### Scenario: Editing without access
- **WHEN** a rider without access edits their limits
- **THEN** the edit is saved, and no verdict is shown

### Requirement: On-device access check
The system SHALL grant access when StoreKit reports a verified, non-revoked transaction for either plan that is active, in a free trial, or in a billing grace period. The check SHALL use only StoreKit on the device, with no server, and SHALL work offline using StoreKit's locally available entitlements.

#### Scenario: Offline subscriber
- **WHEN** an active subscriber opens the app with no connection
- **THEN** access is granted

#### Scenario: Billing grace period
- **WHEN** a renewal payment failed and the subscription is in its billing grace period
- **THEN** access is granted

#### Scenario: Unverified transaction
- **WHEN** StoreKit reports a transaction that fails verification
- **THEN** it does not grant access

### Requirement: Live entitlement updates
While running, the system SHALL react to purchases, renewals, expirations, refunds and revocations without a relaunch.

#### Scenario: Refund
- **WHEN** Apple refunds the rider's subscription while the app is open
- **THEN** access ends and gated content locks without a relaunch

#### Scenario: Purchase on another device
- **WHEN** the rider subscribes on their iPad
- **THEN** access is granted on their iPhone the next time StoreKit delivers the update

### Requirement: Effects of losing access
When access ends, the system SHALL remove all pending ride notifications, show widgets and the watch app in a locked state with no weather information, stop making weather requests, and keep every profile and setting. When access returns, notifications, widgets and the watch SHALL resume without the rider reconfiguring anything.

#### Scenario: Trial ends without purchase
- **WHEN** the free trial ends and the rider hasn't subscribed
- **THEN** no further ride notifications arrive, widgets show a subscribe prompt, and preferences remain

#### Scenario: Resubscribing
- **WHEN** a lapsed rider subscribes again
- **THEN** notifications are rescheduled and widgets show verdicts again, with their old settings

### Requirement: Restore, manage and redeem
The system SHALL offer Restore Purchases, open the system subscription-management screen, and allow offer-code redemption through the system sheet.

#### Scenario: Restore on a new phone
- **WHEN** a subscriber on a new iPhone taps Restore Purchases
- **THEN** access is granted when StoreKit returns their active subscription
