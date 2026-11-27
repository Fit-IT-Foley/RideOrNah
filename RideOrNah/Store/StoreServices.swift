import Entitlements
import Foundation
import Presentation
import StoreKit

enum PurchaseOutcome {
    case purchased, pending, cancelled
}

enum StoreError: Error {
    /// The plans haven't loaded, so there's nothing to buy.
    case unavailable
}

/// The App Store as the access controller sees it, so tests and UI tests can stand in for it.
protocol StoreServing: AnyObject {
    /// Access as known without asking, for stand-ins; nil for the real store.
    var knownActive: Bool? { get }
    /// The two plans, or none when the App Store can't be reached.
    func loadOffers() async -> [PlanOffer]
    /// The latest status of each plan in the group, from the device.
    func facts() async -> [SubscriptionFact]
    func purchase(_ plan: Plan) async throws -> PurchaseOutcome
    /// Asks the App Store for the account's transactions. It can show a sign-in prompt.
    func sync() async throws
    /// Fires on every new transaction: purchases on other devices, renewals, refunds, revocations.
    func updates() -> AsyncStream<Void>
}

/// StoreKit 2.
final class LiveStore: StoreServing {
    private var products: [Plan: Product] = [:]

    var knownActive: Bool? { nil }

    func loadOffers() async -> [PlanOffer] {
        guard let loaded = try? await Product.products(for: Plan.allCases.map(\.productID)) else { return [] }
        var offers: [PlanOffer] = []
        for product in loaded {
            guard let plan = Plan(productID: product.id) else { continue }
            products[plan] = product
            var trial: PlanOffer.Trial?
            if let subscription = product.subscription, await subscription.isEligibleForIntroOffer,
                let intro = subscription.introductoryOffer, intro.paymentMode == .freeTrial
            {
                trial = PlanOffer.Trial(value: intro.period.value, unit: Self.unit(intro.period.unit))
            }
            offers.append(
                PlanOffer(
                    plan: plan, displayPrice: product.displayPrice, price: product.price,
                    priceFormat: product.priceFormatStyle, trial: trial))
        }
        return offers
    }

    func facts() async -> [SubscriptionFact] {
        if products.isEmpty { _ = await loadOffers() }
        guard let product = products.values.first, let statuses = try? await product.subscription?.status else {
            return []
        }
        return statuses.compactMap(Self.fact)
    }

    func purchase(_ plan: Plan) async throws -> PurchaseOutcome {
        guard let product = products[plan] else { throw StoreError.unavailable }
        switch try await product.purchase() {
        case .success(let verification):
            if case .verified(let transaction) = verification { await transaction.finish() }
            return .purchased
        case .pending:
            return .pending
        case .userCancelled:
            return .cancelled
        @unknown default:
            return .cancelled
        }
    }

    func sync() async throws { try await AppStore.sync() }

    func updates() -> AsyncStream<Void> {
        AsyncStream { continuation in
            let task = Task {
                for await update in Transaction.updates {
                    if case .verified(let transaction) = update { await transaction.finish() }
                    continuation.yield()
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    static func fact(_ status: Product.SubscriptionInfo.Status) -> SubscriptionFact? {
        let transaction: Transaction
        let isVerified: Bool
        switch status.transaction {
        case .verified(let value):
            transaction = value
            isVerified = true
        case .unverified(let value, _):
            transaction = value
            isVerified = false
        }
        guard let plan = Plan(productID: transaction.productID) else { return nil }
        let state: SubscriptionFact.State =
            if transaction.revocationDate != nil {
                .revoked
            } else {
                switch status.state {
                case .subscribed: .subscribed
                case .inGracePeriod: .inGracePeriod
                case .inBillingRetryPeriod: .inBillingRetry
                case .revoked: .revoked
                default: .expired
                }
            }
        let renews = (try? status.renewalInfo.payloadValue.willAutoRenew) ?? false
        return SubscriptionFact(
            plan: plan, state: state, isVerified: isVerified, isTrial: transaction.offer?.paymentMode == .freeTrial,
            willRenew: renews, expiresAt: transaction.expirationDate)
    }

    static func unit(_ unit: Product.SubscriptionPeriod.Unit) -> PlanOffer.Trial.Unit {
        switch unit {
        case .day: .day
        case .week: .week
        case .month: .month
        case .year: .year
        @unknown default: .day
        }
    }
}

#if DEBUG
    /// A stand-in App Store for UI tests (`-accessStub active|inactive`) and app-hosted tests,
    /// which change `current` and call `emit()` the way StoreKit delivers a transaction.
    final class StubStore: StoreServing {
        static let offers = [
            PlanOffer(
                plan: .annual, displayPrice: "$19.99", price: 19.99, priceFormat: .currency(code: "USD"),
                trial: .init(value: 1, unit: .week)),
            PlanOffer(
                plan: .monthly, displayPrice: "$2.99", price: 2.99, priceFormat: .currency(code: "USD"),
                trial: .init(value: 1, unit: .week)),
        ]

        static func trial(_ plan: Plan) -> SubscriptionFact {
            SubscriptionFact(plan: plan, state: .subscribed, isVerified: true, isTrial: true)
        }

        var current: [SubscriptionFact]
        private(set) var syncCount = 0
        private var continuation: AsyncStream<Void>.Continuation?

        init(active: Bool) { current = active ? [Self.trial(.annual)] : [] }

        var knownActive: Bool? { AccessPolicy.access(from: current).isActive }
        func loadOffers() async -> [PlanOffer] { Self.offers }
        func facts() async -> [SubscriptionFact] { current }

        func purchase(_ plan: Plan) async throws -> PurchaseOutcome {
            current = [Self.trial(plan)]
            return .purchased
        }

        func sync() async throws { syncCount += 1 }

        func updates() -> AsyncStream<Void> {
            AsyncStream { continuation = $0 }
        }

        /// Delivers a transaction update, as StoreKit does after a purchase elsewhere or a refund.
        func emit() { continuation?.yield() }
    }
#endif
