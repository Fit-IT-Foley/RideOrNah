import Foundation
import VerdictEngine

/// A latitude and longitude in degrees.
public struct GeoCoordinate: Sendable, Codable, Equatable {
    public var latitude: Double
    public var longitude: Double

    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }

    /// Great-circle distance in metres.
    public func distance(to other: GeoCoordinate) -> Double {
        let lat1 = latitude * .pi / 180
        let lat2 = other.latitude * .pi / 180
        let dLat = lat2 - lat1
        let dLon = (other.longitude - longitude) * .pi / 180
        let a = sin(dLat / 2) * sin(dLat / 2) + cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
        return 2 * SampleLayout.earthRadius * atan2(sqrt(a), sqrt(1 - a))
    }
}

/// A coordinate rounded to 0.01° (about 1.1 km), the only precision ever sent to the weather
/// service or used as a cache key. Stored as whole hundredths, so equal roundings compare equal.
public struct RoundedCoordinate: Sendable, Codable, Hashable {
    public let latitudeHundredths: Int
    public let longitudeHundredths: Int

    public init(_ coordinate: GeoCoordinate) {
        latitudeHundredths = Int((coordinate.latitude * 100).rounded())
        longitudeHundredths = Int((coordinate.longitude * 100).rounded())
    }

    public var latitude: Double { Double(latitudeHundredths) / 100 }
    public var longitude: Double { Double(longitudeHundredths) / 100 }

    /// A file-name-safe key such as `40.71_-74.01`.
    public var key: String { String(format: "%.2f_%.2f", latitude, longitude) }
}

/// One point the forecast is fetched for.
public struct SamplePoint: Sendable, Equatable {
    public var position: SamplePosition
    /// Where the geometry puts the point, before rounding.
    public var exact: GeoCoordinate
    public var coordinate: RoundedCoordinate
}

/// Which points to sample for an evaluation location and ride radius.
public enum SampleLayout {
    static let earthRadius = 6_371_000.0
    /// Radii at or above this also get a ring at half the radius. Set in kilometres so the
    /// 50 mi (80 km) preset qualifies.
    public static let innerRingThreshold = 80_000.0

    /// The center alone for a local radius (0); otherwise the center and eight compass points at
    /// `radius` metres, plus eight at half the radius from 80 km up. Center first, then clockwise
    /// from north, inner before outer.
    public static func points(center: GeoCoordinate, radius: Double) -> [SamplePoint] {
        var points = [SamplePoint(position: .center, exact: center, coordinate: RoundedCoordinate(center))]
        guard radius > 0 else { return points }
        var rings: [(SamplePosition.Ring, Double)] = [(.outer, radius)]
        if radius >= innerRingThreshold { rings.insert((.inner, radius / 2), at: 0) }
        for direction in CompassDirection.allCases {
            for (ring, distance) in rings {
                let exact = destination(from: center, bearing: Double(direction.rawValue) * 45, distance: distance)
                points.append(
                    SamplePoint(position: .ring(direction, ring), exact: exact, coordinate: RoundedCoordinate(exact)))
            }
        }
        return points
    }

    /// The point `distance` metres from `start` along `bearing` degrees, on a sphere.
    static func destination(from start: GeoCoordinate, bearing: Double, distance: Double) -> GeoCoordinate {
        let angular = distance / earthRadius
        let theta = bearing * .pi / 180
        let lat1 = start.latitude * .pi / 180
        let lon1 = start.longitude * .pi / 180
        let lat2 = asin(sin(lat1) * cos(angular) + cos(lat1) * sin(angular) * cos(theta))
        let lon2 = lon1 + atan2(sin(theta) * sin(angular) * cos(lat1), cos(angular) - sin(lat1) * sin(lat2))
        var longitude = lon2 * 180 / .pi
        longitude = (longitude + 540).truncatingRemainder(dividingBy: 360) - 180
        return GeoCoordinate(latitude: lat2 * 180 / .pi, longitude: longitude)
    }
}
