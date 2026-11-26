import Foundation
import VerdictEngine

/// An official alert as one point's forecast reports it.
public struct PointAlert: Sendable, Codable, Hashable {
    public var name: String
    public var severity: AlertSeverity
    /// Nil when the source gives no period; the engine then applies it to today.
    public var active: DateInterval?

    public init(name: String, severity: AlertSeverity, active: DateInterval? = nil) {
        self.name = name
        self.severity = severity
        self.active = active
    }
}

/// Everything fetched for one sample point, in the engine's SI types.
public struct PointForecast: Sendable, Codable, Equatable {
    public var hours: [HourConditions]
    public var days: [DaySun]
    /// Nil when the source offers no alerts for the point's region.
    public var alerts: [PointAlert]?

    public init(hours: [HourConditions], days: [DaySun], alerts: [PointAlert]?) {
        self.hours = hours
        self.days = days
        self.alerts = alerts
    }
}

/// Why a fetch failed, in the terms the rider is told.
public enum WeatherSourceError: Error, Sendable, Equatable {
    case offline
    case serviceUnavailable
    case notAuthorized
}

/// A source of forecasts for single points.
public protocol WeatherProviding: Sendable {
    /// False for sources that never touch the network, such as fixtures. Their fetches don't
    /// count as requests and don't use the daily budget.
    var makesNetworkRequests: Bool { get }

    /// Hourly conditions across `hours`, sun times for each day in `days`, and alerts.
    func forecast(at coordinate: RoundedCoordinate, hours: DateInterval, days: DateInterval)
        async throws(WeatherSourceError)
        -> PointForecast
}
