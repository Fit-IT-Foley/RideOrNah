import Foundation

/// A soft and a hard limit for one value. Either may be unset. A value exactly at a limit
/// breaches it.
public struct ThresholdLimit: Sendable, Codable, Equatable {
    public var isEnabled: Bool
    public var soft: Double?
    public var hard: Double?

    public init(isEnabled: Bool = true, soft: Double? = nil, hard: Double? = nil) {
        self.isEnabled = isEnabled
        self.soft = soft
        self.hard = hard
    }

    public static let off = ThresholdLimit(isEnabled: false)
}

/// Precipitation limits. Chance is a fraction (0–1) and intensity is mm/h. While enabled,
/// thunderstorms and hail are always a hard breach.
public struct PrecipitationLimit: Sendable, Codable, Equatable {
    public var isEnabled: Bool
    public var chance: ThresholdLimit
    public var intensity: ThresholdLimit

    public init(isEnabled: Bool = true, chance: ThresholdLimit = .off, intensity: ThresholdLimit = .off) {
        self.isEnabled = isEnabled
        self.chance = chance
        self.intensity = intensity
    }

    public static let off = PrecipitationLimit(isEnabled: false)
}

/// Roads count as wet for `duration` seconds after the last hour with measurable precipitation.
public struct WetRoadsLimit: Sendable, Codable, Equatable {
    public var isEnabled: Bool
    public var duration: TimeInterval
    public var severity: Severity

    public init(isEnabled: Bool = true, duration: TimeInterval = 0, severity: Severity = .soft) {
        self.isEnabled = isEnabled
        self.duration = duration
        self.severity = severity
    }

    public static let off = WetRoadsLimit(isEnabled: false)
}

/// Ice risk is always a hard breach. `threshold` is the air temperature in °C at or below which
/// damp roads count as icy.
public struct IceLimit: Sendable, Codable, Equatable {
    public var isEnabled: Bool
    public var threshold: Double

    public init(isEnabled: Bool = true, threshold: Double = 3) {
        self.isEnabled = isEnabled
        self.threshold = threshold
    }

    public static let off = IceLimit(isEnabled: false)
}

/// A rider's limits for every factor, in SI units. The memberwise defaults turn everything off;
/// default values for new profiles belong to rider preferences, not to the engine.
public struct Limits: Sendable, Codable, Equatable {
    public var precipitation: PrecipitationLimit
    /// Air temperature, °C, at or below.
    public var cold: ThresholdLimit
    /// Feels-like temperature, °C, at or above.
    public var heat: ThresholdLimit
    /// Relative humidity, 0–1, at or above.
    public var humidity: ThresholdLimit
    /// Sustained wind, m/s, at or above.
    public var wind: ThresholdLimit
    /// Gusts, m/s, at or above.
    public var gusts: ThresholdLimit
    /// UV index, at or above.
    public var uv: ThresholdLimit
    /// Visibility, metres, at or below.
    public var visibility: ThresholdLimit
    public var wetRoads: WetRoadsLimit
    public var ice: IceLimit
    /// Official alerts: severe and extreme are hard, moderate is soft, minor is ignored.
    public var alertsEnabled: Bool

    public init(
        precipitation: PrecipitationLimit = .off, cold: ThresholdLimit = .off, heat: ThresholdLimit = .off,
        humidity: ThresholdLimit = .off, wind: ThresholdLimit = .off, gusts: ThresholdLimit = .off,
        uv: ThresholdLimit = .off, visibility: ThresholdLimit = .off, wetRoads: WetRoadsLimit = .off,
        ice: IceLimit = .off, alertsEnabled: Bool = false
    ) {
        self.precipitation = precipitation
        self.cold = cold
        self.heat = heat
        self.humidity = humidity
        self.wind = wind
        self.gusts = gusts
        self.uv = uv
        self.visibility = visibility
        self.wetRoads = wetRoads
        self.ice = ice
        self.alertsEnabled = alertsEnabled
    }
}

/// A recurring stretch of the day the rider rides. Times are wall-clock minutes after midnight
/// in the device's time zone, and a window never crosses midnight.
public struct RideWindow: Sendable, Codable, Equatable {
    /// Calendar weekday numbers: 1 is Sunday, 7 is Saturday.
    public var weekdays: Set<Int>
    public var start: Int
    public var end: Int

    public init(weekdays: Set<Int>, start: Int, end: Int) {
        self.weekdays = weekdays
        self.start = start
        self.end = end
    }

    /// A window from hour and minute pairs, such as `RideWindow(weekdays: [2], from: (7, 30), to: (9, 0))`.
    public init(weekdays: Set<Int>, from start: (hour: Int, minute: Int), to end: (hour: Int, minute: Int)) {
        self.init(weekdays: weekdays, start: start.hour * 60 + start.minute, end: end.hour * 60 + end.minute)
    }
}

/// The parts of the active profile the engine needs.
public struct ProfileSnapshot: Sendable, Codable, Equatable {
    public var limits: Limits
    public var windows: [RideWindow]
    /// The shortest stretch worth suggesting as a ride opportunity, in seconds.
    public var minimumRideDuration: TimeInterval

    public init(limits: Limits, windows: [RideWindow], minimumRideDuration: TimeInterval = 2 * 3600) {
        self.limits = limits
        self.windows = windows
        self.minimumRideDuration = minimumRideDuration
    }
}
