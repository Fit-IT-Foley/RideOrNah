import Foundation
import VerdictEngine
import WeatherData

/// First-run setup as a state machine. The app saves it after every step, so quitting resumes
/// where the rider left off.
public struct FirstRunFlow: Sendable, Codable, Equatable {
    public enum Step: String, Sendable, Codable, CaseIterable {
        case style
        case limits
        case locationExplanation
        /// Reached when location permission is denied: setup continues with a saved place.
        case addSavedLocation
        /// The daily ride notification: turn it on at a time, or skip without asking permission.
        case notifications
        case done
    }

    public static let defaultProfileName = "My Bike"

    public private(set) var step: Step = .style
    public private(set) var draft: RiderProfile
    public private(set) var savedLocations: [SavedLocation] = []
    public private(set) var notifications = NotificationSettings()

    public init(now: Date = Date()) {
        draft = .defaults(named: Self.defaultProfileName, now: now)
    }

    public mutating func choose(_ style: RidingStyle) {
        draft.windows = style.windows
        step = .limits
    }

    /// Keeps the default limits, or takes the reviewed ones.
    public mutating func confirmLimits(_ limits: Limits? = nil) {
        if let limits { draft.limits = limits }
        step = .locationExplanation
    }

    public mutating func locationPermission(granted: Bool) {
        step = granted ? .notifications : .addSavedLocation
    }

    public mutating func addSavedLocation(named name: String, at coordinate: GeoCoordinate) {
        savedLocations.append(SavedLocation(name: name, coordinate: coordinate))
        step = .notifications
    }

    /// Turns the daily notification on at `minutesAfterMidnight`; call after permission is granted.
    public mutating func enableNotifications(at minutesAfterMidnight: Int) {
        notifications = NotificationSettings(isEnabled: true, minutesAfterMidnight: minutesAfterMidnight)
        step = .done
    }

    /// Leaves the daily notification off; no permission is asked.
    public mutating func skipNotifications() {
        notifications = NotificationSettings()
        step = .done
    }

    /// The rider's preferences once setup is done: an active "My Bike" profile and any saved place.
    public func finish(now: Date = Date()) -> Preferences {
        var profile = draft
        profile.modifiedAt = now
        var preferences = Preferences(firstProfile: profile, now: now)
        preferences.savedLocations = savedLocations
        preferences.notifications = notifications
        if let first = savedLocations.first { preferences.evaluationLocation = .saved(first.id) }
        return preferences
    }
}
