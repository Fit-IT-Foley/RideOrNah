import Foundation
import Testing
import WeatherData

@testable import RiderSettings

struct PreferencesStoreTests {
    /// Exactly what version 1 of the app writes for `SettingsFixtures.v1`.
    static let v1JSON = #"""
        {"activeProfileID":"11111111-1111-1111-1111-111111111111","deletedProfiles":[],"evaluationLocation":{"saved":{"_0":"22222222-2222-2222-2222-222222222222"}},"profiles":[{"id":"11111111-1111-1111-1111-111111111111","limits":{"alertsEnabled":true,"cold":{"hard":4.4,"isEnabled":true,"soft":10},"gusts":{"hard":17.88,"isEnabled":true,"soft":13.41},"heat":{"hard":37.8,"isEnabled":true,"soft":32},"humidity":{"isEnabled":false,"soft":0.85},"ice":{"isEnabled":true,"threshold":3},"precipitation":{"chance":{"hard":0.6,"isEnabled":true,"soft":0.3},"intensity":{"hard":1,"isEnabled":true,"soft":0.1},"isEnabled":true},"uv":{"isEnabled":true,"soft":8},"visibility":{"hard":400,"isEnabled":true,"soft":1609},"wetRoads":{"duration":7200,"isEnabled":true,"severity":1},"wind":{"hard":13.41,"isEnabled":true,"soft":8.94}},"minimumRideDuration":7200,"modifiedAt":802605600,"name":"Commuter","radius":40,"windows":[{"end":540,"start":420,"weekdays":[2,3,4,5,6]},{"end":1080,"start":960,"weekdays":[2,3,4,5,6]}]}],"recentProfileIDs":["11111111-1111-1111-1111-111111111111"],"savedLocations":[{"id":"22222222-2222-2222-2222-222222222222","location":{"rounded":{"latitudeHundredths":4071,"longitudeHundredths":-7401}},"name":"Home"}],"schemaVersion":1,"sharedModifiedAt":802605600,"syncEnabled":true,"unitPreference":"imperial"}
        """#

    // Scenario: rider-profiles: App update
    @Test("App update")
    func appUpdate() {
        let harness = StoreHarness()
        defer { harness.tearDown() }
        harness.defaults.set(Data(Self.v1JSON.utf8), forKey: PreferencesStore.preferencesKey)
        #expect(harness.store().load() == SettingsFixtures.v1)
    }

    @Test func savesAndLoadsLocally() {
        let harness = StoreHarness()
        defer { harness.tearDown() }
        let store = harness.store()
        #expect(store.load() == nil)
        store.save(SettingsFixtures.v1)
        #expect(store.load() == SettingsFixtures.v1)
    }

    @Test func deviceOnlyValuesStayOutOfPreferencesAndICloud() {
        let harness = StoreHarness()
        defer { harness.tearDown() }
        let cloud = FakeCloud()
        let store = harness.store(cloud: cloud)
        store.lastSeenLocation = SettingsFixtures.brooklyn
        store.save(SettingsFixtures.v1)
        #expect(store.lastSeenLocation == GeoCoordinate(latitude: 40.68, longitude: -73.94))
        #expect(!cloud.keys.contains { $0.hasPrefix("device.") })
    }

    // Scenario: rider-profiles: New iPhone
    @Test("New iPhone")
    func newIPhone() throws {
        let cloud = FakeCloud()
        let first = StoreHarness()
        defer { first.tearDown() }
        var preferences = SettingsFixtures.v1
        preferences.addProfile(named: "Adventure", now: SettingsFixtures.morning)
        first.store(cloud: cloud).save(preferences)

        let second = StoreHarness()
        defer { second.tearDown() }
        let store = second.store(cloud: cloud)
        #expect(store.load() == nil)
        let restored = try #require(store.cloudPreferences())
        #expect(Set(restored.profiles.map(\.name)) == ["Commuter", "Adventure"])
        #expect(restored.savedLocations.map(\.name) == ["Home"])
    }

    // Scenario: rider-profiles: No iCloud
    @Test("No iCloud")
    func noICloud() {
        let harness = StoreHarness()
        defer { harness.tearDown() }
        let cloud = FakeCloud()
        cloud.isAvailable = false
        let store = harness.store(cloud: cloud)
        store.save(SettingsFixtures.v1)
        #expect(store.load() == SettingsFixtures.v1)
        #expect(cloud.storage.isEmpty)
        #expect(store.cloudPreferences() == nil)
    }

    // Scenario: rider-profiles: Turning sync off
    @Test("Turning sync off")
    func turningSyncOff() {
        let harness = StoreHarness()
        defer { harness.tearDown() }
        let cloud = FakeCloud()
        let store = harness.store(cloud: cloud)
        var preferences = SettingsFixtures.v1
        store.save(preferences)
        let uploaded = cloud.storage

        preferences.syncEnabled = false
        preferences.rename(
            preferences.activeProfileID, to: "Offline only", now: SettingsFixtures.morning.addingTimeInterval(60))
        store.save(preferences)
        #expect(cloud.storage == uploaded)
        #expect(store.load()?.activeProfile.name == "Offline only")
    }

    @Test func latestEditWinsPerProfileAcrossDevices() throws {
        let cloud = FakeCloud()
        let phoneA = StoreHarness()
        let phoneB = StoreHarness()
        defer {
            phoneA.tearDown()
            phoneB.tearDown()
        }
        var onA = SettingsFixtures.preferences(["Commuter", "Adventure"])
        phoneA.store(cloud: cloud).save(onA)
        var onB = try #require(phoneB.store(cloud: cloud).cloudPreferences())

        // B renames Commuter later; A renames Adventure later.
        let commuter = onA.profiles[0].id
        let adventure = onA.profiles[1].id
        onB.rename(commuter, to: "Daily", now: SettingsFixtures.morning.addingTimeInterval(120))
        phoneB.store(cloud: cloud).save(onB)
        onA.rename(adventure, to: "Trail", now: SettingsFixtures.morning.addingTimeInterval(60))
        phoneA.store(cloud: cloud).save(onA)

        let merged = phoneA.store(cloud: cloud).merge(into: onA)
        #expect(merged.profile(commuter)?.name == "Daily")
        #expect(merged.profile(adventure)?.name == "Trail")
    }

    @Test func deletedProfilesStayDeleted() throws {
        let cloud = FakeCloud()
        let phoneA = StoreHarness()
        let phoneB = StoreHarness()
        defer {
            phoneA.tearDown()
            phoneB.tearDown()
        }
        var onA = SettingsFixtures.preferences(["Commuter", "Adventure"])
        phoneA.store(cloud: cloud).save(onA)
        let onB = try #require(phoneB.store(cloud: cloud).cloudPreferences())
        try onA.deleteProfile(onA.profiles[1].id, now: SettingsFixtures.morning.addingTimeInterval(60))
        phoneA.store(cloud: cloud).save(onA)
        let merged = phoneB.store(cloud: cloud).merge(into: onB)
        #expect(merged.profiles.map(\.name) == ["Commuter"])
    }
}
