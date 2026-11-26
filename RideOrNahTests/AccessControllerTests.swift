import Entitlements
import Foundation
import Presentation
import SharedContainer
import Testing
import VerdictEngine

@testable import RideOrNah

/// Access as StoreKit's updates change it, with a stand-in store, so these run on every
/// simulator and in CI. `StoreKitIntegrationTests` drive the real store where StoreKit Testing works.
@MainActor
struct AccessControllerTests {
    /// A controller on a stand-in store, writing its access mirror somewhere only this test reads.
    static func controller(active: Bool = false) throws -> (AccessController, StubStore, SharedContainer) {
        let url = FileManager.default.temporaryDirectory.appending(path: "Access-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        let container = SharedContainer.resolve(groupIdentifier: "test") { _ in url }
        let store = StubStore(active: active)
        return (AccessController(store: store, container: container), store, container)
    }

    /// Waits for an update to be handled.
    static func eventually(_ condition: () -> Bool) async -> Bool {
        for _ in 0..<100 where !condition() { try? await Task.sleep(for: .milliseconds(20)) }
        return condition()
    }

    // Scenario: subscription: Purchase on another device
    @Test("Purchase on another device")
    func purchaseOnAnotherDevice() async throws {
        let (access, store, container) = try Self.controller()
        await access.start()
        #expect(access.access == .inactive)
        store.current = [StubStore.trial(.annual)]
        store.emit()
        #expect(await Self.eventually { access.access.isActive })
        #expect(access.access == .active(plan: .annual, inTrial: true, renews: true))
        #expect(container.readAccessMirror()?.isActive == true)
    }

    // Scenario: subscription: Refund
    @Test("Refund")
    func refund() async throws {
        let (access, store, container) = try Self.controller(active: true)
        await access.start()
        #expect(access.access.isActive)
        store.current = [SubscriptionFact(plan: .annual, state: .revoked, isVerified: true)]
        store.emit()
        #expect(await Self.eventually { !access.access.isActive })
        #expect(container.readAccessMirror()?.isActive == false)
    }

    // Scenario: subscription: Restore on a new phone
    @Test("Restore on a new phone")
    func restoreOnANewPhone() async throws {
        let (access, store, _) = try Self.controller()
        await access.start()
        #expect(access.access == .inactive)
        // The App Store returns the account's subscription when asked.
        store.current = [SubscriptionFact(plan: .monthly, state: .subscribed, isVerified: true)]
        await access.restore()
        #expect(store.syncCount == 1)
        #expect(access.access == .active(plan: .monthly, inTrial: false, renews: true))
        #expect(access.message == nil)
    }

    @Test("Restore with nothing to restore")
    func restoreWithNothing() async throws {
        let (access, _, _) = try Self.controller()
        await access.restore()
        #expect(access.access == .inactive)
        #expect(access.message == "No active subscription was found for this Apple Account.")
    }

    // Scenario: subscription: Trial ends without purchase
    // Scenario: subscription: Resubscribing
    @Test("Trial ends, then resubscribing")
    func trialEndsThenResubscribing() async throws {
        let clock = MovableClock(NotificationCoordinatorTests.june(8, 5))
        let (coordinator, center, model) = NotificationCoordinatorTests.coordinator(clock: clock)
        let (access, store, container) = try Self.controller(active: true)
        access.connect(forecast: coordinator.forecast, notifications: coordinator)
        await access.start()
        #expect(await coordinator.enable(at: 6 * 60 + 30))
        #expect(center.pending.count == 3)
        let settings = model.preferences?.notifications

        // The trial runs out; the app finds out on its next check.
        store.current = [SubscriptionFact(plan: .annual, state: .expired, isVerified: true, isTrial: true)]
        await access.refresh()
        #expect(access.access == .inactive)
        #expect(center.pending.isEmpty)
        #expect(coordinator.forecast.isLocked)
        #expect(coordinator.forecast.outlook == nil)
        #expect(container.readAccessMirror()?.isActive == false)
        #expect(model.preferences?.notifications == settings)

        store.current = [SubscriptionFact(plan: .annual, state: .subscribed, isVerified: true)]
        store.emit()
        #expect(await Self.eventually { access.access.isActive })
        #expect(await Self.eventually { center.pending.count == 3 })
        #expect(!coordinator.forecast.isLocked)
        #expect(model.preferences?.notifications == settings)
        #expect(container.readAccessMirror()?.isActive == true)
    }

    @Test("A purchase that isn't available says so")
    func purchaseUnavailable() async throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "Access-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        let access = AccessController(
            store: LiveStore(), container: SharedContainer.resolve(groupIdentifier: "test") { _ in url })
        await access.purchase(.annual)
        #expect(access.message == "The App Store isn't reachable right now. Try again in a moment.")
    }
}

/// Locking without StoreKit, so it runs on every simulator.
@MainActor
struct AccessGatingTests {
    // Scenario: subscription: Editing without access
    @Test("Editing without access")
    func editingWithoutAccess() async throws {
        let clock = MovableClock(NotificationCoordinatorTests.june(8, 6))
        let (forecast, model) = ForecastControllerTests.controller(clock: clock)
        forecast.setLocked(true)
        await forecast.refresh(.foreground)
        #expect(forecast.snapshot == nil)
        var profile = try #require(model.preferences?.activeProfile)
        profile.limits.humidity = ThresholdLimit(isEnabled: true, soft: 0.8, hard: 0.95)
        model.update { $0.update(profile) }
        #expect(model.store.load()?.activeProfile.limits.humidity.hard == 0.95)
        await forecast.refresh(.foreground)
        #expect(forecast.snapshot == nil)
        #expect(forecast.outlook == nil)
    }

    @Test("A cancelled trial schedules nothing past its end")
    func cancelledTrial() async throws {
        let clock = MovableClock(NotificationCoordinatorTests.june(8, 5))
        let (coordinator, center, _) = NotificationCoordinatorTests.coordinator(clock: clock)
        await coordinator.forecast.refresh(.foreground)
        coordinator.accessEnds = { NotificationCoordinatorTests.june(9, 12) }
        #expect(await coordinator.enable(at: 6 * 60 + 30))
        #expect(center.pending.count == 2)
    }
}
