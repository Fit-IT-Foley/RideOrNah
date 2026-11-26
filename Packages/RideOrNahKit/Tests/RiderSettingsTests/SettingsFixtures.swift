import Foundation
import VerdictEngine
import WeatherData

@testable import RiderSettings

enum SettingsFixtures {
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        return calendar
    }()
    /// Monday 8 June 2026, 06:00 New York.
    static let morning = calendar.date(from: DateComponents(year: 2026, month: 6, day: 8, hour: 6))!
    static let newYork = GeoCoordinate(latitude: 40.712776, longitude: -74.005974)
    static let brooklyn = GeoCoordinate(latitude: 40.678178, longitude: -73.944158)

    static func preferences(_ profiles: [String] = ["Commuter"]) -> Preferences {
        var preferences = Preferences(
            firstProfile: .defaults(named: profiles[0], style: .commute, now: morning), now: morning)
        for name in profiles.dropFirst() { preferences.addProfile(named: name, now: morning) }
        return preferences
    }

    /// Preferences as version 1 of the app saves them, with fixed IDs and dates.
    static let v1: Preferences = {
        let commuter = RiderProfile(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!, name: "Commuter", modifiedAt: morning,
            limits: .defaults, windows: RidingStyle.commute.windows, radius: .km40,
            minimumRideDuration: 2 * 3600)
        var preferences = Preferences(firstProfile: commuter, now: morning)
        preferences.savedLocations = [
            SavedLocation(
                id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!, name: "Home", coordinate: newYork)
        ]
        preferences.evaluationLocation = .saved(UUID(uuidString: "22222222-2222-2222-2222-222222222222")!)
        preferences.unitPreference = .imperial
        return preferences
    }()
}

/// An in-memory stand-in for the iCloud key-value store, shared between "devices" in tests.
final class FakeCloud: KeyValueSyncing {
    var isAvailable = true
    var storage: [String: Data] = [:]
    func data(forKey key: String) -> Data? { storage[key] }
    func set(_ data: Data?, forKey key: String) { storage[key] = data }
    var keys: [String] { Array(storage.keys) }
}

/// A store on a fresh defaults suite, removed after the test.
struct StoreHarness {
    let suite = "rideornah-settings-\(UUID().uuidString)"
    var defaults: UserDefaults { UserDefaults(suiteName: suite)! }
    func store(cloud: KeyValueSyncing? = nil) -> PreferencesStore { PreferencesStore(defaults: defaults, cloud: cloud) }
    func tearDown() { UserDefaults.standard.removePersistentDomain(forName: suite) }
}
