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
        #expect(flow.step == .done)
        let preferences = flow.finish(now: SettingsFixtures.morning)
        #expect(preferences.activeProfile.name == "My Bike")
        #expect(preferences.activeProfile.windows == RidingStyle.commute.windows)
        #expect(preferences.activeProfile.limits == .defaults)
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
}
