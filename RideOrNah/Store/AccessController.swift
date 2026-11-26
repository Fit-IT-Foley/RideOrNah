import Entitlements
import Foundation
import Observation
import Presentation
import SharedContainer
import StoreKit

/// The one place the app talks to StoreKit: loads the plans, works out access from the
/// device's verified transactions, and follows purchases, renewals, refunds and revocations
/// as they happen.
@Observable
final class AccessController {
    private(set) var access = Access.inactive
    private(set) var offers: [PlanOffer] = []
    /// When access ends because the subscription won't renew; nothing is scheduled past it.
    private(set) var endsAt: Date?
    /// True until the first check finishes, so the app doesn't flash a locked screen.
    private(set) var isChecking = true
    private(set) var isPurchasing = false
    /// Why the last purchase or restore didn't work, shown on the paywall.
    private(set) var message: String?
    /// Whether the paywall is on screen.
    var showsPaywall = false
    /// Called after access changes, so weather and notifications can follow.
    var onChange: ((Access) async -> Void)?

    /// Asks the App Store for the account's transactions. It can show a sign-in prompt, so
    /// tests replace it.
    var sync: () async throws -> Void = { try await AppStore.sync() }

    private let container: SharedContainer
    private let stub: Access?
    private var products: [Plan: Product] = [:]
    private var updates: Task<Void, Never>?

    init(container: SharedContainer, stub: Access? = nil) {
        self.container = container
        self.stub = stub
    }

    /// The live controller, or, in debug builds, `-accessStub active|inactive` for UI tests.
    static func live() -> AccessController {
        #if DEBUG
            if let stub = UserDefaults.standard.string(forKey: "accessStub") {
                return AccessController(
                    container: .current(),
                    stub: stub == "active" ? .active(plan: .annual, inTrial: true, renews: true) : .inactive)
            }
        #endif
        return AccessController(container: .current())
    }

    /// Starts following transactions and makes the first check. Call once at launch.
    func start() async {
        if let stub {
            offers = Self.stubOffers
            await set(stub)
            return
        }
        guard updates == nil else { return }
        updates = Task { [weak self] in
            for await update in Transaction.updates {
                if case .verified(let transaction) = update { await transaction.finish() }
                await self?.refresh()
            }
        }
        await loadProducts()
        await refresh()
    }

    /// Whether access was active at the last check, from the access mirror, so launch doesn't
    /// fetch weather for a lapsed rider or lock a subscriber before StoreKit answers.
    var lastKnownActive: Bool { stub?.isActive ?? container.readAccessMirror()?.isActive ?? false }

    /// Loads the plans again, after they failed to load.
    func retry() async {
        await loadProducts()
        await refresh()
    }

    /// Re-reads the subscription group's status from StoreKit.
    func refresh() async {
        guard stub == nil else { return }
        var facts: [SubscriptionFact] = []
        if let product = products.values.first, let statuses = try? await product.subscription?.status {
            facts = statuses.compactMap(Self.fact)
        }
        endsAt = AccessPolicy.ends(from: facts)
        await set(AccessPolicy.access(from: facts))
    }

    func purchase(_ plan: Plan) async {
        message = nil
        if stub != nil {
            await set(.active(plan: plan, inTrial: true, renews: true))
            return
        }
        guard let product = products[plan] else {
            message = "The App Store isn't reachable right now. Try again in a moment."
            return
        }
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            switch try await product.purchase() {
            case .success(let verification):
                if case .verified(let transaction) = verification { await transaction.finish() }
                await refresh()
            case .pending:
                message = "Your purchase is waiting for approval."
            case .userCancelled:
                break
            @unknown default:
                break
            }
        } catch {
            message = "The purchase didn't go through. Nothing was charged."
        }
    }

    func restore() async {
        message = nil
        guard stub == nil else { return }
        if products.isEmpty { await loadProducts() }
        do {
            try await sync()
        } catch {
            message = "Couldn't reach the App Store to restore. Try again in a moment."
        }
        await refresh()
        if !access.isActive, message == nil { message = "No active subscription was found for this Apple Account." }
    }

    private func set(_ new: Access) async {
        let changed = new != access || isChecking
        access = new
        isChecking = false
        container.writeAccessMirror(AccessMirror(isActive: new.isActive, checkedAt: Date()))
        if new.isActive { showsPaywall = false }
        if changed { await onChange?(new) }
    }

    private func loadProducts() async {
        guard let loaded = try? await Product.products(for: Plan.allCases.map(\.productID)) else { return }
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
        self.offers = offers
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

    #if DEBUG
        static let stubOffers = [
            PlanOffer(
                plan: .annual, displayPrice: "$29.99", price: 29.99, priceFormat: .currency(code: "USD"),
                trial: .init(value: 1, unit: .week)),
            PlanOffer(
                plan: .monthly, displayPrice: "$4.99", price: 4.99, priceFormat: .currency(code: "USD"),
                trial: .init(value: 1, unit: .week)),
        ]
    #else
        static let stubOffers: [PlanOffer] = []
    #endif
}
