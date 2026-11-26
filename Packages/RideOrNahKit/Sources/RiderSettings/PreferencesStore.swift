import Foundation
import WeatherData

/// A key-value store that syncs through the rider's iCloud, or a fake in tests.
public protocol KeyValueSyncing: AnyObject {
    /// False when the device has no iCloud account.
    var isAvailable: Bool { get }
    func data(forKey key: String) -> Data?
    func set(_ data: Data?, forKey key: String)
    var keys: [String] { get }
}

/// `NSUbiquitousKeyValueStore`, available when an iCloud account is signed in.
public final class CloudKeyValueStore: KeyValueSyncing {
    let store = NSUbiquitousKeyValueStore.default
    public init() {}
    public var isAvailable: Bool { FileManager.default.ubiquityIdentityToken != nil }
    public func data(forKey key: String) -> Data? { store.data(forKey: key) }
    public func set(_ data: Data?, forKey key: String) {
        if let data { store.set(data, forKey: key) } else { store.removeObject(forKey: key) }
        store.synchronize()
    }
    public var keys: [String] { Array(store.dictionaryRepresentation.keys) }
}

/// Saves preferences in app-group defaults (so widgets read them) and mirrors them to iCloud
/// when sync is on. Device-only values (last-seen location, setup progress) never sync.
public final class PreferencesStore {
    static let preferencesKey = "preferences.v1"
    static let lastSeenKey = "device.lastSeenLocation"
    static let firstRunKey = "device.firstRun"
    static let sharedCloudKey = "shared"
    static let profilePrefix = "profile."
    static let deletedPrefix = "deleted."

    let defaults: UserDefaults
    let cloud: KeyValueSyncing?

    public init(defaults: UserDefaults, cloud: KeyValueSyncing?) {
        self.defaults = defaults
        self.cloud = cloud
    }

    // MARK: Local

    /// Saved preferences, or nil before first-run setup has finished on this device.
    public func load() -> Preferences? {
        defaults.data(forKey: Self.preferencesKey).flatMap { try? JSONDecoder().decode(Preferences.self, from: $0) }
    }

    /// Saves locally, then uploads to iCloud if sync is on and available.
    public func save(_ preferences: Preferences) {
        if let data = try? JSONEncoder().encode(preferences) { defaults.set(data, forKey: Self.preferencesKey) }
        if preferences.syncEnabled { upload(preferences) }
    }

    public var lastSeenLocation: GeoCoordinate? {
        get {
            defaults.data(forKey: Self.lastSeenKey).flatMap { try? JSONDecoder().decode(GeoCoordinate.self, from: $0) }
        }
        set {
            let rounded = newValue.map { StoredCoordinate($0).coordinate }
            defaults.set(rounded.flatMap { try? JSONEncoder().encode($0) }, forKey: Self.lastSeenKey)
        }
    }

    public var firstRunProgress: FirstRunFlow? {
        get {
            defaults.data(forKey: Self.firstRunKey).flatMap { try? JSONDecoder().decode(FirstRunFlow.self, from: $0) }
        }
        set { defaults.set(newValue.flatMap { try? JSONEncoder().encode($0) }, forKey: Self.firstRunKey) }
    }

    // MARK: iCloud

    struct Shared: Codable, Equatable {
        var activeProfileID: UUID
        var recentProfileIDs: [UUID]
        var savedLocations: [SavedLocation]
        var evaluationLocation: EvaluationLocation
        var backgroundSource: BackgroundSource?
        var unitPreference: UnitPreference
        var todayRadius: TodayRadius?
        var modifiedAt: Date
    }

    func upload(_ preferences: Preferences) {
        guard let cloud, cloud.isAvailable else { return }
        let encoder = JSONEncoder()
        for profile in preferences.profiles {
            let key = Self.profilePrefix + profile.id.uuidString
            let existing = cloud.data(forKey: key).flatMap { try? JSONDecoder().decode(RiderProfile.self, from: $0) }
            if existing.map({ $0.modifiedAt < profile.modifiedAt }) ?? true {
                cloud.set(try? encoder.encode(profile), forKey: key)
            }
        }
        for (id, deletedAt) in preferences.deletedProfiles {
            cloud.set(try? encoder.encode(deletedAt), forKey: Self.deletedPrefix + id.uuidString)
            cloud.set(nil, forKey: Self.profilePrefix + id.uuidString)
        }
        let shared = Shared(
            activeProfileID: preferences.activeProfileID, recentProfileIDs: preferences.recentProfileIDs,
            savedLocations: preferences.savedLocations, evaluationLocation: preferences.evaluationLocation,
            backgroundSource: preferences.backgroundSource, unitPreference: preferences.unitPreference,
            todayRadius: preferences.todayRadius, modifiedAt: preferences.sharedModifiedAt)
        let existingShared = cloud.data(forKey: Self.sharedCloudKey).flatMap {
            try? JSONDecoder().decode(Shared.self, from: $0)
        }
        if existingShared.map({ $0.modifiedAt < shared.modifiedAt }) ?? true {
            cloud.set(try? encoder.encode(shared), forKey: Self.sharedCloudKey)
        }
    }

    /// Preferences from iCloud alone, for a device that hasn't been set up (a new iPhone). Nil
    /// when sync isn't available or iCloud holds no profiles.
    public func cloudPreferences() -> Preferences? {
        guard let cloud, cloud.isAvailable else { return nil }
        let profiles = cloudProfiles(cloud).values.sorted { $0.name < $1.name }
        guard let first = profiles.first else { return nil }
        var preferences = Preferences(firstProfile: first, now: first.modifiedAt)
        preferences.profiles = profiles
        if let shared = cloudShared(cloud) { apply(shared, to: &preferences) }
        return preferences
    }

    /// Merges what iCloud holds into `preferences`: each profile takes the latest edit, deleted
    /// profiles stay deleted, and shared settings take the latest change.
    public func merge(into preferences: Preferences) -> Preferences {
        guard preferences.syncEnabled, let cloud, cloud.isAvailable else { return preferences }
        var merged = preferences
        let deletions = cloudDeletions(cloud).merging(preferences.deletedProfiles) { max($0, $1) }
        merged.deletedProfiles = deletions
        for (id, remote) in cloudProfiles(cloud) where deletions[id] == nil {
            if let index = merged.profiles.firstIndex(where: { $0.id == id }) {
                if remote.modifiedAt > merged.profiles[index].modifiedAt { merged.profiles[index] = remote }
            } else {
                merged.profiles.append(remote)
            }
        }
        let survivors = merged.profiles.filter { deletions[$0.id] == nil }
        if !survivors.isEmpty { merged.profiles = survivors }
        if let shared = cloudShared(cloud), shared.modifiedAt > merged.sharedModifiedAt { apply(shared, to: &merged) }
        if !merged.profiles.contains(where: { $0.id == merged.activeProfileID }) {
            merged.activeProfileID =
                merged.recentProfileIDs.first { id in merged.profiles.contains { $0.id == id } }
                ?? merged.profiles[0].id
        }
        return merged
    }

    func apply(_ shared: Shared, to preferences: inout Preferences) {
        if preferences.profiles.contains(where: { $0.id == shared.activeProfileID }) {
            preferences.activeProfileID = shared.activeProfileID
        }
        preferences.recentProfileIDs = shared.recentProfileIDs
        preferences.savedLocations = shared.savedLocations
        preferences.evaluationLocation = shared.evaluationLocation
        preferences.backgroundSource = shared.backgroundSource
        preferences.unitPreference = shared.unitPreference
        preferences.todayRadius = shared.todayRadius
        preferences.sharedModifiedAt = shared.modifiedAt
    }

    func cloudProfiles(_ cloud: KeyValueSyncing) -> [UUID: RiderProfile] {
        var profiles: [UUID: RiderProfile] = [:]
        for key in cloud.keys where key.hasPrefix(Self.profilePrefix) {
            if let profile = cloud.data(forKey: key).flatMap({ try? JSONDecoder().decode(RiderProfile.self, from: $0) })
            {
                profiles[profile.id] = profile
            }
        }
        return profiles
    }

    func cloudDeletions(_ cloud: KeyValueSyncing) -> [UUID: Date] {
        var deletions: [UUID: Date] = [:]
        for key in cloud.keys where key.hasPrefix(Self.deletedPrefix) {
            if let id = UUID(uuidString: String(key.dropFirst(Self.deletedPrefix.count))),
                let date = cloud.data(forKey: key).flatMap({ try? JSONDecoder().decode(Date.self, from: $0) })
            {
                deletions[id] = date
            }
        }
        return deletions
    }

    func cloudShared(_ cloud: KeyValueSyncing) -> Shared? {
        cloud.data(forKey: Self.sharedCloudKey).flatMap { try? JSONDecoder().decode(Shared.self, from: $0) }
    }
}
