import Entitlements
import Foundation
import Presentation
import SharedContainer
import StoreKit
import StoreKitTest
import Testing

@testable import RideOrNah

/// Whether StoreKit Testing can load the plans in this simulator.
func storeKitTestingWorks() async -> Bool {
    guard (try? SKTestSession(configurationFileNamed: "RideOrNah")) != nil else { return false }
    let products = try? await Product.products(for: Plan.allCases.map(\.productID))
    return products?.count == Plan.allCases.count
}

/// The real StoreKit store against `StoreKit/RideOrNah.storekit` with StoreKit Testing: purchases
/// outside the app, refunds and a lapsed trial, with no sandbox account. Serialized, since the
/// test session is shared. StoreKit Testing loads no plans in some simulators (iOS 26 locally,
/// and CI's runners), so the suite runs only where it can; `AccessControllerTests` cover the same
/// scenarios with a stand-in store everywhere.
@MainActor
@Suite(
    .serialized,
    .enabled("StoreKit Testing loads the plans here") { await storeKitTestingWorks() })
struct StoreKitIntegrationTests {

    static func session() throws -> SKTestSession {
        let session = try SKTestSession(configurationFileNamed: "RideOrNah")
        session.resetToDefaultState()
        session.clearTransactions()
        session.disableDialogs = true
        return session
    }

    /// A controller writing its access mirror somewhere only this test reads.
    static func controller() throws -> (AccessController, SharedContainer) {
        let url = FileManager.default.temporaryDirectory.appending(path: "Access-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        let container = SharedContainer.resolve(groupIdentifier: "test") { _ in url }
        return (AccessController(store: LiveStore(), container: container), container)
    }

    /// Waits for StoreKit to deliver an update.
    static func eventually(_ condition: () -> Bool) async -> Bool {
        for _ in 0..<100 where !condition() { try? await Task.sleep(for: .milliseconds(100)) }
        return condition()
    }

    // Trial eligibility isn't checked here: StoreKit Testing reports riders as ineligible even
    // when the purchase gets the trial. PaywallTests cover both wordings.
    @Test("Plans load from the App Store")
    func plansLoad() async throws {
        _ = try Self.session()
        let (store, _) = try Self.controller()
        await store.start()
        #expect(store.access == .inactive)
        #expect(Set(store.offers.map(\.plan)) == [.monthly, .annual])
        #expect(store.offers.first { $0.plan == .annual }?.displayPrice == "$29.99")
        #expect(store.offers.first { $0.plan == .monthly }?.displayPrice == "$4.99")
    }

    @Test("Purchase on another device")
    func purchaseOnAnotherDevice() async throws {
        let session = try Self.session()
        let (store, container) = try Self.controller()
        await store.start()
        #expect(store.access == .inactive)
        _ = try await session.buyProduct(identifier: Plan.annual.productID)
        #expect(await Self.eventually { store.access.isActive })
        #expect(store.access == .active(plan: .annual, inTrial: true, renews: true))
        #expect(container.readAccessMirror()?.isActive == true)
    }

    @Test("Refund")
    func refund() async throws {
        let session = try Self.session()
        let (store, container) = try Self.controller()
        let transaction = try await session.buyProduct(identifier: Plan.monthly.productID)
        await store.start()
        #expect(store.access.isActive)
        try session.refundTransaction(identifier: UInt(transaction.id))
        #expect(await Self.eventually { !store.access.isActive })
        #expect(container.readAccessMirror()?.isActive == false)
    }

    // The rider cancels during the trial and it runs out; StoreKit's fast clock makes each
    // period last 2 seconds.
    @Test("Trial ends, then resubscribing")
    func trialEndsThenResubscribing() async throws {
        let session = try Self.session()
        session.timeRate = .oneRenewalEveryTwoSeconds
        let clock = MovableClock(NotificationCoordinatorTests.june(8, 5))
        let (coordinator, center, model) = NotificationCoordinatorTests.coordinator(clock: clock)
        let (store, container) = try Self.controller()
        store.connect(forecast: coordinator.forecast, notifications: coordinator)
        let trial = try await session.buyProduct(identifier: Plan.annual.productID)
        try session.disableAutoRenewForTransaction(identifier: UInt(trial.id))
        await store.start()
        #expect(await coordinator.enable(at: 6 * 60 + 30))
        let settings = model.preferences?.notifications

        // The app re-checks on every foreground and background refresh.
        for _ in 0..<50 where store.access.isActive {
            try? await Task.sleep(for: .milliseconds(200))
            await store.refresh()
        }
        #expect(store.access == .inactive)
        #expect(center.pending.isEmpty)
        #expect(coordinator.forecast.isLocked)
        #expect(coordinator.forecast.outlook == nil)
        #expect(container.readAccessMirror()?.isActive == false)
        #expect(model.preferences?.notifications == settings)

        _ = try await session.buyProduct(identifier: Plan.annual.productID)
        #expect(await Self.eventually { store.access.isActive })
        #expect(await Self.eventually { center.pending.count == 3 })
        #expect(!coordinator.forecast.isLocked)
        #expect(model.preferences?.notifications == settings)
        #expect(container.readAccessMirror()?.isActive == true)
    }
}
