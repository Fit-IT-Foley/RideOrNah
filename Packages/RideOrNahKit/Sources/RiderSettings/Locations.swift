import Foundation
import WeatherData

public enum LocationError: Error, Equatable {
    case limitReached
}

/// A current-location reading. Approximate readings are used as they are; every reading is
/// rounded to 0.01° before use.
public struct LocationReading: Sendable, Equatable {
    public var coordinate: GeoCoordinate
    public var isApproximate: Bool

    public init(coordinate: GeoCoordinate, isApproximate: Bool) {
        self.coordinate = coordinate
        self.isApproximate = isApproximate
    }

    public var rounded: GeoCoordinate { StoredCoordinate(coordinate).coordinate }
}

extension Preferences {
    public static let maximumSavedLocations = 10

    @discardableResult
    public mutating func addSavedLocation(named name: String, at coordinate: GeoCoordinate, now: Date = Date())
        throws(LocationError) -> SavedLocation
    {
        guard savedLocations.count < Self.maximumSavedLocations else { throw .limitReached }
        let location = SavedLocation(name: name, coordinate: coordinate)
        savedLocations.append(location)
        sharedModifiedAt = now
        return location
    }

    public var canAddSavedLocation: Bool { savedLocations.count < Self.maximumSavedLocations }

    public mutating func renameSavedLocation(_ id: UUID, to name: String, now: Date = Date()) {
        guard let index = savedLocations.firstIndex(where: { $0.id == id }) else { return }
        savedLocations[index].name = name
        sharedModifiedAt = now
    }

    public mutating func deleteSavedLocation(_ id: UUID, now: Date = Date()) {
        savedLocations.removeAll { $0.id == id }
        if evaluationLocation == .saved(id) { evaluationLocation = .current }
        if backgroundSource == .saved(id) { backgroundSource = nil }
        sharedModifiedAt = now
    }

    public mutating func choose(_ location: EvaluationLocation, now: Date = Date()) {
        evaluationLocation = location
        sharedModifiedAt = now
    }

    /// Where Today evaluates: the chosen saved place, or the current location. Falls back to the
    /// first saved place when the current location isn't available; nil when there's nowhere.
    public func evaluationPlace(current: LocationReading?) -> ResolvedLocation? {
        if case .saved(let id) = evaluationLocation, let saved = savedLocations.first(where: { $0.id == id }) {
            return ResolvedLocation(name: saved.name, coordinate: saved.location.coordinate)
        }
        if let current { return ResolvedLocation(name: "Current location", coordinate: current.rounded) }
        return savedLocations.first.map { ResolvedLocation(name: $0.name, coordinate: $0.location.coordinate) }
    }

    /// The rider's choice, or the default: a saved place named "Home", else the last-seen location.
    public var effectiveBackgroundSource: BackgroundSource {
        if let backgroundSource { return backgroundSource }
        if let home = savedLocations.first(where: { $0.name.caseInsensitiveCompare("Home") == .orderedSame }) {
            return .saved(home.id)
        }
        return .lastSeen
    }

    /// Where notifications and widgets evaluate; nil when the last-seen location is needed and
    /// none has been seen, so they ask the rider to open the app.
    public func backgroundPlace(lastSeen: GeoCoordinate?) -> ResolvedLocation? {
        switch effectiveBackgroundSource {
        case .saved(let id):
            return savedLocations.first { $0.id == id }.map {
                ResolvedLocation(name: $0.name, coordinate: $0.location.coordinate)
            }
        case .lastSeen:
            return lastSeen.map {
                ResolvedLocation(name: "Where I last opened the app", coordinate: StoredCoordinate($0).coordinate)
            }
        }
    }
}
