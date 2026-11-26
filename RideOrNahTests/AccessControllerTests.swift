import Entitlements
import Foundation
import Presentation
import SharedContainer
import StoreKitTest
import Testing
import VerdictEngine

@testable import RideOrNah

/// StoreKit Testing works in the iOS 27 simulator and later.
let storeKitTestingWorks = ProcessInfo.processInfo.isOperatingSystemAtLeast(
    OperatingSystemVersion(majorVersion: 27, minorVersion: 0, patchVersion: 0))

/// StoreKit Testing against `StoreKit/RideOrNah.storekit`: purchases outside the app, refunds,
/// expiry and restore, with no sandbox account. Serialized, since the test session is shared.
/// On the iOS 26 simulator StoreKit Testing loads no products and refuses purchases
/// (`.notEntitled`), so these run on iOS 27 and later; CI runs both.
@MainActor
@Suite(
    .serialized,
    .enabled(if: storeKitTestingWorks, "StoreKit Testing needs iOS 27 in the simulator"))
struct AccessControllerTests {

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
        return (AccessController(container: container), container)
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

    // Scenario: subscription: Purchase on another device
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

    // Scenario: subscription: Refund
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

    // Scenario: subscription: Restore on a new phone
    @Test("Restore on a new phone")
    func restoreOnANewPhone() async throws {
        let session = try Self.session()
        _ = try await session.buyProduct(identifier: Plan.annual.productID)
        let (store, _) = try Self.controller()
        // The real sync can ask the rider to sign in; StoreKit Testing already has the purchase.
        store.sync = {}
        #expect(store.access == .inactive)
        await store.restore()
        #expect(store.access.isActive)
        #expect(store.message == nil)
    }

    // The rider cancels during the trial and it runs out; StoreKit's fast clock makes each
    // period last 2 seconds.
    // Scenario: subscription: Trial ends without purchase
    // Scenario: subscription: Resubscribing
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
