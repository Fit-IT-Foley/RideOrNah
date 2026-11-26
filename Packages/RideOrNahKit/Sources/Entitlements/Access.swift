import Foundation

/// A subscription plan. Both are in one App Store subscription group.
public enum Plan: String, Sendable, Codable, CaseIterable, Equatable {
    case monthly, annual

    /// The App Store product ID.
    public var productID: String { "rideornah.\(rawValue)" }

    public init?(productID: String) {
        guard let plan = Plan.allCases.first(where: { $0.productID == productID }) else { return nil }
        self = plan
    }
}

/// What the app reads from StoreKit about one plan's latest transaction.
public struct SubscriptionFact: Sendable, Equatable {
    public enum State: Sendable, Equatable {
        case subscribed, inGracePeriod, inBillingRetry, expired, revoked
    }

    public var plan: Plan
    public var state: State
    /// False when StoreKit couldn't verify the transaction's signature.
    public var isVerified: Bool
    /// True during a free-trial introductory period.
    public var isTrial: Bool
    public var willRenew: Bool
    public var expiresAt: Date?

    public init(
        plan: Plan, state: State, isVerified: Bool, isTrial: Bool = false, willRenew: Bool = true,
        expiresAt: Date? = nil
    ) {
        self.plan = plan
        self.state = state
        self.isVerified = isVerified
        self.isTrial = isTrial
        self.willRenew = willRenew
        self.expiresAt = expiresAt
    }
}

/// Whether the rider can see verdicts.
public enum Access: Sendable, Equatable {
    case active(plan: Plan, inTrial: Bool, renews: Bool)
    case inactive

    public var isActive: Bool {
        if case .active = self { return true }
        return false
    }
}

/// Turns StoreKit facts into access. StoreKit keeps the latest verified status on the device,
/// so this works offline.
public enum AccessPolicy {
    public static func access(from facts: [SubscriptionFact]) -> Access {
        guard let best = granting(facts) else { return .inactive }
        return .active(plan: best.plan, inTrial: best.isTrial, renews: best.willRenew)
    }

    /// When access will end because the subscription won't renew (a cancelled trial, say), so
    /// nothing is scheduled past it. Nil while it renews, or without access.
    public static func ends(from facts: [SubscriptionFact]) -> Date? {
        guard let best = granting(facts), !best.willRenew else { return nil }
        return best.expiresAt
    }

    static func granting(_ facts: [SubscriptionFact]) -> SubscriptionFact? {
        facts.filter { $0.isVerified && ($0.state == .subscribed || $0.state == .inGracePeriod) }
            .max { rank($0.plan) < rank($1.plan) }
    }

    /// The annual plan wins when both grant access, so the current plan is stable.
    static func rank(_ plan: Plan) -> Int { plan == .annual ? 1 : 0 }
}
