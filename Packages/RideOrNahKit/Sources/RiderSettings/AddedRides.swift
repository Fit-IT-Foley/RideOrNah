import Foundation

/// A ride suggestion the rider saved to their calendar. Kept on this device only, so the same
/// stretch isn't offered twice and the ride can be re-checked when the forecast changes.
public struct AddedRide: Sendable, Codable, Equatable {
    public var start: Date
    public var end: Date
    public var profileName: String
    public var placeName: String

    public init(range: DateInterval, profileName: String, placeName: String) {
        start = range.start
        end = range.end
        self.profileName = profileName
        self.placeName = placeName
    }

    public var range: DateInterval { DateInterval(start: start, end: end) }
}

extension PreferencesStore {
    static let addedRidesKey = "device.addedRides"

    /// Rides the rider added to their calendar, never synced.
    public var addedRides: [AddedRide] {
        get {
            defaults.data(forKey: Self.addedRidesKey).flatMap { try? JSONDecoder().decode([AddedRide].self, from: $0) }
                ?? []
        }
        set { defaults.set(try? JSONEncoder().encode(newValue), forKey: Self.addedRidesKey) }
    }

    public func recordAddedRide(_ ride: AddedRide) {
        guard !addedRides.contains(where: { $0.range == ride.range }) else { return }
        addedRides.append(ride)
    }

    /// Forgets rides whose day has passed.
    public func pruneAddedRides(now: Date, calendar: Calendar) {
        let today = calendar.startOfDay(for: now)
        let kept = addedRides.filter { $0.end > today }
        if kept != addedRides { addedRides = kept }
    }
}
