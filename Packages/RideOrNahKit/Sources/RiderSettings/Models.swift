import Foundation
import VerdictEngine
import WeatherData

/// Ride radius presets, stored as kilometres so switching units never changes the radius.
public enum RadiusPreset: Int, Sendable, Codable, CaseIterable {
    case local = 0
    case km16 = 16
    case km40 = 40
    case km80 = 80
    case km160 = 160

    public var metres: Double { Double(rawValue) * 1000 }

    /// "Local", or the kilometres for metric riders, or miles rounded to the nearest 5 for
    /// imperial riders (10, 25, 50, 100).
    public func label(in units: UnitSystem) -> String {
        guard self != .local else { return "Local" }
        switch units {
        case .metric: return "\(rawValue) km"
        case .imperial: return "\(Int((Double(rawValue) / 1.609344 / 5).rounded()) * 5) mi"
        }
    }
}

public enum UnitSystem: String, Sendable, Codable {
    case imperial, metric
}

/// The rider's choice: follow the device region, or a fixed system.
public enum UnitPreference: String, Sendable, Codable, CaseIterable {
    case automatic, imperial, metric

    /// US regions get imperial; every other region metric.
    public func resolved(locale: Locale = .current) -> UnitSystem {
        switch self {
        case .imperial: .imperial
        case .metric: .metric
        case .automatic: locale.measurementSystem == .us ? .imperial : .metric
        }
    }
}

/// Riding-style presets offered in setup. Anytime has no windows, so every day is judged on
/// daylight hours.
public enum RidingStyle: String, Sendable, Codable, CaseIterable {
    case commute, weekends, anytime

    public var windows: [RideWindow] {
        switch self {
        case .commute:
            let weekdays: Set<Int> = [2, 3, 4, 5, 6]
            return [
                RideWindow(weekdays: weekdays, from: (7, 0), to: (9, 0)),
                RideWindow(weekdays: weekdays, from: (16, 0), to: (18, 0)),
            ]
        case .weekends:
            return [RideWindow(weekdays: [1, 7], from: (9, 0), to: (17, 0))]
        case .anytime:
            return []
        }
    }
}

/// A coordinate stored at 0.01° precision.
public struct StoredCoordinate: Sendable, Codable, Hashable {
    public let rounded: RoundedCoordinate

    public init(_ coordinate: GeoCoordinate) {
        rounded = RoundedCoordinate(coordinate)
    }

    public var coordinate: GeoCoordinate { GeoCoordinate(latitude: rounded.latitude, longitude: rounded.longitude) }
}

public struct SavedLocation: Sendable, Codable, Equatable, Identifiable {
    public var id: UUID
    public var name: String
    public var location: StoredCoordinate

    public init(id: UUID = UUID(), name: String, coordinate: GeoCoordinate) {
        self.id = id
        self.name = name
        location = StoredCoordinate(coordinate)
    }
}

/// Where Today evaluates.
public enum EvaluationLocation: Sendable, Codable, Hashable {
    case current
    case saved(UUID)
}

/// Where notifications and widgets evaluate.
public enum BackgroundSource: Sendable, Codable, Hashable {
    case saved(UUID)
    /// The last current location seen while the app was in the foreground.
    case lastSeen
}

/// A place resolved to a name and a rounded coordinate.
public struct ResolvedLocation: Sendable, Equatable {
    public var name: String
    public var coordinate: GeoCoordinate

    public init(name: String, coordinate: GeoCoordinate) {
        self.name = name
        self.coordinate = coordinate
    }
}

/// Today's radius override, valid only on the local day it was set.
public struct TodayRadius: Sendable, Codable, Equatable {
    public var day: String
    public var radius: RadiusPreset
}

public struct RiderProfile: Sendable, Codable, Equatable, Identifiable {
    public var id: UUID
    public var name: String
    /// When the profile last changed; the latest edit wins when devices disagree.
    public var modifiedAt: Date
    public var limits: Limits
    public var windows: [RideWindow]
    public var radius: RadiusPreset
    public var minimumRideDuration: TimeInterval

    public init(
        id: UUID = UUID(), name: String, modifiedAt: Date = Date(), limits: Limits, windows: [RideWindow],
        radius: RadiusPreset, minimumRideDuration: TimeInterval
    ) {
        self.id = id
        self.name = name
        self.modifiedAt = modifiedAt
        self.limits = limits
        self.windows = windows
        self.radius = radius
        self.minimumRideDuration = minimumRideDuration
    }

    /// What the verdict engine needs from this profile.
    public var snapshot: ProfileSnapshot {
        ProfileSnapshot(limits: limits, windows: windows, minimumRideDuration: minimumRideDuration)
    }
}

/// Everything the rider has chosen. Synced through their iCloud when sync is on; the last-seen
/// location and setup progress are stored separately and never sync.
public struct Preferences: Sendable, Codable, Equatable {
    public static let schemaVersion = 1

    public var schemaVersion: Int
    public var profiles: [RiderProfile]
    public var activeProfileID: UUID
    /// Most recently activated first, so deleting the active profile falls back sensibly.
    public var recentProfileIDs: [UUID]
    public var savedLocations: [SavedLocation]
    public var evaluationLocation: EvaluationLocation
    /// Nil means the default: a saved place named "Home" if there is one, else the last-seen location.
    public var backgroundSource: BackgroundSource?
    public var unitPreference: UnitPreference
    public var syncEnabled: Bool
    public var todayRadius: TodayRadius?
    /// When anything outside the profiles last changed.
    public var sharedModifiedAt: Date
    /// Deleted profiles and when, so another device's copy doesn't bring them back.
    public var deletedProfiles: [UUID: Date]

    public init(firstProfile: RiderProfile, now: Date = Date()) {
        schemaVersion = Self.schemaVersion
        profiles = [firstProfile]
        activeProfileID = firstProfile.id
        recentProfileIDs = [firstProfile.id]
        savedLocations = []
        evaluationLocation = .current
        backgroundSource = nil
        unitPreference = .automatic
        syncEnabled = true
        todayRadius = nil
        sharedModifiedAt = now
        deletedProfiles = [:]
    }
}
