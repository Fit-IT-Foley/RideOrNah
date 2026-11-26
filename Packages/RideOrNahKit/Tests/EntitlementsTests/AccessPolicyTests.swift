import Entitlements
import Foundation
import Testing

struct AccessPolicyTests {
    // StoreKit serves the last verified status from the device, so offline is the same input.
    // Scenario: subscription: Offline subscriber
    @Test("Offline subscriber")
    func offlineSubscriber() {
        let facts = [SubscriptionFact(plan: .monthly, state: .subscribed, isVerified: true)]
        #expect(AccessPolicy.access(from: facts) == .active(plan: .monthly, inTrial: false, renews: true))
    }

    // Scenario: subscription: Billing grace period
    @Test("Billing grace period")
    func billingGracePeriod() {
        let grace = [SubscriptionFact(plan: .annual, state: .inGracePeriod, isVerified: true)]
        #expect(AccessPolicy.access(from: grace).isActive)
        let retry = [SubscriptionFact(plan: .annual, state: .inBillingRetry, isVerified: true)]
        #expect(AccessPolicy.access(from: retry) == .inactive)
    }

    // Scenario: subscription: Unverified transaction
    @Test("Unverified transaction")
    func unverifiedTransaction() {
        let facts = [SubscriptionFact(plan: .annual, state: .subscribed, isVerified: false)]
        #expect(AccessPolicy.access(from: facts) == .inactive)
    }

    @Test("Expired, revoked and none")
    func expiredRevokedAndNone() {
        #expect(AccessPolicy.access(from: []) == .inactive)
        for state in [SubscriptionFact.State.expired, .revoked] {
            #expect(
                AccessPolicy.access(from: [SubscriptionFact(plan: .monthly, state: state, isVerified: true)])
                    == .inactive)
        }
    }

    @Test("Trial, and annual wins over monthly")
    func trialAndAnnualWins() {
        let facts = [
            SubscriptionFact(plan: .monthly, state: .subscribed, isVerified: true),
            SubscriptionFact(plan: .annual, state: .subscribed, isVerified: true, isTrial: true, willRenew: false),
        ]
        #expect(AccessPolicy.access(from: facts) == .active(plan: .annual, inTrial: true, renews: false))
    }

    @Test("End of access")
    func endOfAccess() {
        let end = Date(timeIntervalSince1970: 1_780_000_000)
        let cancelled = [
            SubscriptionFact(plan: .annual, state: .subscribed, isVerified: true, willRenew: false, expiresAt: end)
        ]
        #expect(AccessPolicy.ends(from: cancelled) == end)
        let renewing = [SubscriptionFact(plan: .annual, state: .subscribed, isVerified: true, expiresAt: end)]
        #expect(AccessPolicy.ends(from: renewing) == nil)
        #expect(AccessPolicy.ends(from: []) == nil)
    }

    @Test("Product IDs")
    func productIDs() {
        #expect(Plan.annual.productID == "rideornah.annual")
        #expect(Plan(productID: "rideornah.monthly") == .monthly)
        #expect(Plan(productID: "something.else") == nil)
    }
}
