import Entitlements
import Foundation
import Observation
import Presentation
import SharedContainer

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

    let store: any StoreServing
    private let container: SharedContainer
    private var updates: Task<Void, Never>?

    init(store: any StoreServing, container: SharedContainer) {
        self.store = store
        self.container = container
    }

    /// The live controller, or, in debug builds, `-accessStub active|inactive` for UI tests.
    static func live() -> AccessController {
        #if DEBUG
            if let stub = UserDefaults.standard.string(forKey: "accessStub") {
                return AccessController(store: StubStore(active: stub == "active"), container: .current())
            }
        #endif
        return AccessController(store: LiveStore(), container: .current())
    }

    /// Starts following transactions and makes the first check. Call once at launch.
    func start() async {
        guard updates == nil else { return }
        let stream = store.updates()
        updates = Task { [weak self] in
            for await _ in stream { await self?.refresh() }
        }
        offers = await store.loadOffers()
        await refresh()
    }

    /// Whether access was active at the last check, from the access mirror, so launch doesn't
    /// fetch weather for a lapsed rider or lock a subscriber before StoreKit answers.
    var lastKnownActive: Bool { store.knownActive ?? container.readAccessMirror()?.isActive ?? false }

    /// Loads the plans again, after they failed to load.
    func retry() async {
        offers = await store.loadOffers()
        await refresh()
    }

    /// Re-reads the subscription group's status.
    func refresh() async {
        let facts = await store.facts()
        endsAt = AccessPolicy.ends(from: facts)
        await set(AccessPolicy.access(from: facts))
    }

    func purchase(_ plan: Plan) async {
        message = nil
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            switch try await store.purchase(plan) {
            case .purchased: await refresh()
            case .pending: message = "Your purchase is waiting for approval."
            case .cancelled: break
            }
        } catch StoreError.unavailable {
            message = "The App Store isn't reachable right now. Try again in a moment."
        } catch {
            message = "The purchase didn't go through. Nothing was charged."
        }
    }

    func restore() async {
        message = nil
        do {
            try await store.sync()
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
}
