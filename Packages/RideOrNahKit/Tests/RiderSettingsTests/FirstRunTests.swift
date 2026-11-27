import Foundation
import Testing
import VerdictEngine

@testable import RiderSettings

struct FirstRunTests {
    // Scenario: rider-profiles: Quick setup
    @Test("Quick setup")
    func quickSetup() {
        var flow = FirstRunFlow(now: SettingsFixtures.morning)
        flow.choose(.commute)
        flow.confirmLimits()
        flow.locationPermission(granted: true)
        #expect(flow.step == .notifications)
        flow.skipNotifications()
        #expect(flow.step == .done)
        let preferences = flow.finish(now: SettingsFixtures.morning)
        #expect(preferences.activeProfile.name == "My Bike")
        #expect(preferences.activeProfile.windows == RidingStyle.commute.windows)
        #expect(preferences.activeProfile.limits == .defaults)
    }

    // Scenario: rider-profiles: Turning factors off during setup
    @Test("Turning factors off during setup")
    func turningFactorsOff() {
        var flow = FirstRunFlow(now: SettingsFixtures.morning)
        flow.choose(.commute)
        var limits = Limits.defaults
        limits.precipitation.isEnabled = false
        limits.heat.isEnabled = false
        flow.confirmLimits(limits)
        flow.locationPermission(granted: true)
        flow.skipNotifications()
        let kept = flow.finish(now: SettingsFixtures.morning).activeProfile.limits
        #expect(!kept.precipitation.isEnabled)
        #expect(!kept.heat.isEnabled)
        var rest = kept
        rest.precipitation.isEnabled = true
        rest.heat.isEnabled = true
        #expect(rest == .defaults)
    }

    // Scenario: rider-profiles: Interrupted setup
    @Test("Interrupted setup")
    func interruptedSetup() {
        let harness = StoreHarness()
        defer { harness.tearDown() }
        var flow = FirstRunFlow(now: SettingsFixtures.morning)
        flow.choose(.weekends)
        harness.store().firstRunProgress = flow

        let resumed = harness.store().firstRunProgress
        #expect(resumed?.step == .limits)
        #expect(resumed?.draft.windows == RidingStyle.weekends.windows)
    }

    // Scenario: ride-locations: Permission denied
    @Test("Permission denied")
    func permissionDenied() {
        var flow = FirstRunFlow(now: SettingsFixtures.morning)
        flow.choose(.commute)
        flow.confirmLimits()
        flow.locationPermission(granted: false)
        #expect(flow.step == .addSavedLocation)
        flow.addSavedLocation(named: "Home", at: SettingsFixtures.newYork)
        #expect(flow.step == .notifications)
        flow.skipNotifications()
        #expect(flow.step == .done)
        let preferences = flow.finish()
        #expect(preferences.evaluationPlace(current: nil)?.name == "Home")
    }

    @Test func reviewedLimitsAreKept() {
        var flow = FirstRunFlow(now: SettingsFixtures.morning)
        flow.choose(.anytime)
        var limits = Limits.defaults
        limits.cold.soft = 7
        flow.confirmLimits(limits)
        #expect(flow.finish().activeProfile.limits.cold.soft == 7)
    }

    // Scenario: ride-notifications: Turning it on during setup
    @Test("Turning it on during setup")
    func turningItOnDuringSetup() {
        var flow = FirstRunFlow(now: SettingsFixtures.morning)
        flow.choose(.commute)
        flow.confirmLimits()
        flow.locationPermission(granted: true)
        flow.enableNotifications(at: 5 * 60 + 45)
        #expect(flow.step == .done)
        let notifications = flow.finish().notifications
        #expect(notifications.isEnabled)
        #expect(notifications.minutesAfterMidnight == 345)
    }

    // Scenario: ride-notifications: Skipping the step
    @Test("Skipping the step")
    func skippingTheStep() {
        var flow = FirstRunFlow(now: SettingsFixtures.morning)
        flow.choose(.commute)
        flow.confirmLimits()
        flow.locationPermission(granted: true)
        flow.skipNotifications()
        #expect(flow.finish().notifications.isEnabled == false)
    }

    // Scenario: ride-notifications: Weekend rider default
    @Test("Weekend rider default")
    func weekendRiderDefault() {
        let profile = RiderProfile.defaults(named: "Weekend", style: .weekends)
        #expect(NotificationSettings().weekdays(for: profile) == [1, 7])
    }

    // Scenario: ride-notifications: Anytime rider default
    @Test("Anytime rider default")
    func anytimeRiderDefault() {
        let profile = RiderProfile.defaults(named: "Any", style: .anytime)
        #expect(NotificationSettings().weekdays(for: profile) == Set(1...7))
    }
}
