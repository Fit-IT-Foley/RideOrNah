import Foundation
import VerdictEngine
import WeatherData

extension Limits {
    /// The limits every new profile starts with, in SI units (see the rider-profiles spec).
    public static let defaults = Limits(
        precipitation: PrecipitationLimit(
            chance: ThresholdLimit(soft: 0.3, hard: 0.6), intensity: ThresholdLimit(soft: 0.1, hard: 1)),
        cold: ThresholdLimit(soft: 10, hard: 4.4),
        heat: ThresholdLimit(soft: 32, hard: 37.8),
        humidity: ThresholdLimit(isEnabled: false, soft: 0.85),
        wind: ThresholdLimit(soft: 8.94, hard: 13.41),
        gusts: ThresholdLimit(soft: 13.41, hard: 17.88),
        uv: ThresholdLimit(soft: 8),
        visibility: ThresholdLimit(soft: 1609, hard: 400),
        wetRoads: WetRoadsLimit(duration: 2 * 3600, severity: .soft),
        ice: IceLimit(threshold: 3),
        alertsEnabled: true)
}

extension RiderProfile {
    public static let defaultMinimumRideDuration: TimeInterval = 2 * 3600

    /// A new profile: default limits, a 25 mi (40 km) radius, a 2-hour minimum ride, and the
    /// style's windows.
    public static func defaults(named name: String, style: RidingStyle = .anytime, now: Date = Date()) -> RiderProfile {
        RiderProfile(
            name: name, modifiedAt: now, limits: .defaults, windows: style.windows, radius: .km40,
            minimumRideDuration: defaultMinimumRideDuration)
    }

    /// Back to the default limits, keeping name, windows and radius.
    public mutating func resetLimits(now: Date = Date()) {
        limits = .defaults
        modifiedAt = now
    }
}

public enum ProfileError: Error, Equatable {
    case lastProfile
    case unknownProfile
}

extension Preferences {
    public var activeProfile: RiderProfile {
        profiles.first { $0.id == activeProfileID } ?? profiles[0]
    }

    public func profile(_ id: UUID) -> RiderProfile? { profiles.first { $0.id == id } }

    /// Only possible while another profile exists.
    public var canDeleteProfiles: Bool { profiles.count > 1 }

    @discardableResult
    public mutating func addProfile(named name: String, now: Date = Date()) -> RiderProfile {
        let profile = RiderProfile.defaults(named: name, now: now)
        profiles.append(profile)
        return profile
    }

    public mutating func update(_ profile: RiderProfile, now: Date = Date()) {
        guard let index = profiles.firstIndex(where: { $0.id == profile.id }) else { return }
        var profile = profile
        profile.modifiedAt = now
        profiles[index] = profile
    }

    public mutating func rename(_ id: UUID, to name: String, now: Date = Date()) {
        guard var profile = profile(id) else { return }
        profile.name = name
        update(profile, now: now)
    }

    @discardableResult
    public mutating func duplicate(_ id: UUID, now: Date = Date()) -> RiderProfile? {
        guard var copy = profile(id) else { return nil }
        copy.id = UUID()
        copy.name += " copy"
        copy.modifiedAt = now
        profiles.append(copy)
        return copy
    }

    /// Makes `id` the active profile; every verdict then uses its limits, windows and radius.
    public mutating func activate(_ id: UUID, now: Date = Date()) throws(ProfileError) {
        guard profile(id) != nil else { throw .unknownProfile }
        activeProfileID = id
        recentProfileIDs.removeAll { $0 == id }
        recentProfileIDs.insert(id, at: 0)
        sharedModifiedAt = now
    }

    /// Deleting the active profile activates the most recently used one left.
    public mutating func deleteProfile(_ id: UUID, now: Date = Date()) throws(ProfileError) {
        guard profile(id) != nil else { throw .unknownProfile }
        guard canDeleteProfiles else { throw .lastProfile }
        profiles.removeAll { $0.id == id }
        recentProfileIDs.removeAll { $0 == id }
        deletedProfiles[id] = now
        if activeProfileID == id {
            let next =
                recentProfileIDs.first { candidate in profiles.contains { $0.id == candidate } } ?? profiles[0].id
            try activate(next, now: now)
        }
        sharedModifiedAt = now
    }

    // MARK: Radius

    /// Today's override if it was set today, else the active profile's default.
    public func radius(on date: Date, calendar: Calendar) -> RadiusPreset {
        if let override = todayRadius, override.day == Self.dayString(date, calendar: calendar) {
            return override.radius
        }
        return activeProfile.radius
    }

    public mutating func setTodayRadius(_ radius: RadiusPreset, now: Date, calendar: Calendar) {
        todayRadius = TodayRadius(day: Self.dayString(now, calendar: calendar), radius: radius)
        sharedModifiedAt = now
    }

    /// Clears an override from an earlier day. Call when the local date changes.
    public mutating func clearExpiredOverrides(now: Date, calendar: Calendar) {
        if let override = todayRadius, override.day != Self.dayString(now, calendar: calendar) {
            todayRadius = nil
        }
    }

    /// The active profile and today's radius, which every verdict is evaluated with.
    public func evaluationSettings(now: Date, calendar: Calendar) -> (profile: ProfileSnapshot, radius: RadiusPreset) {
        (activeProfile.snapshot, radius(on: now, calendar: calendar))
    }

    static func dayString(_ date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
}
