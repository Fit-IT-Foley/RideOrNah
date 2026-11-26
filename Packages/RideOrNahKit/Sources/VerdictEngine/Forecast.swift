import Foundation

/// Conditions that matter regardless of the numbers.
public struct HazardFlags: OptionSet, Sendable, Codable, Hashable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }

    public static let thunderstorm = HazardFlags(rawValue: 1 << 0)
    public static let hail = HazardFlags(rawValue: 1 << 1)
    /// Snow, sleet, freezing rain or wintry mix.
    public static let frozenPrecipitation = HazardFlags(rawValue: 1 << 2)
    public static let fog = HazardFlags(rawValue: 1 << 3)
}

public enum CompassDirection: Int, Sendable, Codable, CaseIterable, Comparable {
    case n, ne, e, se, s, sw, w, nw

    public static func < (lhs: CompassDirection, rhs: CompassDirection) -> Bool { lhs.rawValue < rhs.rawValue }
}

/// Where a sample point sits in the ride radius: the evaluation location itself, or a point in
/// one of the eight directions on the inner (half radius) or outer (full radius) ring.
public enum SamplePosition: Hashable, Sendable, Codable, Comparable {
    case center
    case ring(CompassDirection, Ring)

    public enum Ring: Int, Sendable, Codable, Comparable {
        case inner, outer
        public static func < (lhs: Ring, rhs: Ring) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    public var direction: CompassDirection? {
        if case .ring(let direction, _) = self { return direction }
        return nil
    }

    private var sortKey: Int {
        switch self {
        case .center: -1
        case .ring(let direction, let ring): direction.rawValue * 2 + ring.rawValue
        }
    }

    public static func < (lhs: SamplePosition, rhs: SamplePosition) -> Bool { lhs.sortKey < rhs.sortKey }
}

/// One forecast hour at one sample point, in SI units. A nil value is missing from the forecast.
public struct HourConditions: Sendable, Codable, Equatable {
    /// The start of the hour.
    public var start: Date
    /// Air temperature, °C.
    public var temperature: Double?
    /// Feels-like temperature, °C.
    public var feelsLike: Double?
    /// Relative humidity, 0–1.
    public var humidity: Double?
    /// Sustained wind, m/s.
    public var windSpeed: Double?
    /// Gusts, m/s.
    public var windGust: Double?
    public var uvIndex: Double?
    /// Visibility, metres.
    public var visibility: Double?
    /// Precipitation chance, 0–1.
    public var precipitationChance: Double?
    /// Precipitation intensity, mm/h.
    public var precipitationIntensity: Double?
    public var hazards: HazardFlags

    public init(
        start: Date, temperature: Double?, feelsLike: Double?, humidity: Double?, windSpeed: Double?,
        windGust: Double?, uvIndex: Double?, visibility: Double?, precipitationChance: Double?,
        precipitationIntensity: Double?, hazards: HazardFlags = []
    ) {
        self.start = start
        self.temperature = temperature
        self.feelsLike = feelsLike
        self.humidity = humidity
        self.windSpeed = windSpeed
        self.windGust = windGust
        self.uvIndex = uvIndex
        self.visibility = visibility
        self.precipitationChance = precipitationChance
        self.precipitationIntensity = precipitationIntensity
        self.hazards = hazards
    }

    /// Precipitation chance, temperature, feels-like and sustained wind. An hour without all four
    /// counts as having no data.
    var hasCoreValues: Bool {
        precipitationChance != nil && temperature != nil && feelsLike != nil && windSpeed != nil
    }
}

/// Hourly forecast for one sample point. A point whose request failed is passed with no hours,
/// so the engine can report it as missing.
public struct SampleForecast: Sendable, Codable, Equatable {
    public var position: SamplePosition
    public var hours: [HourConditions]

    public init(position: SamplePosition, hours: [HourConditions]) {
        self.position = position
        self.hours = hours
    }
}

public enum AlertSeverity: String, Sendable, Codable, CaseIterable {
    case minor, moderate, severe, extreme
}

/// An official weather alert covering some of the sample points.
public struct AlertInfo: Sendable, Codable, Equatable {
    public var name: String
    public var severity: AlertSeverity
    public var positions: Set<SamplePosition>
    /// When the alert is in effect. Nil when the source gives no period; it then applies to today.
    public var active: DateInterval?

    public init(name: String, severity: AlertSeverity, positions: Set<SamplePosition>, active: DateInterval? = nil) {
        self.name = name
        self.severity = severity
        self.positions = positions
        self.active = active
    }
}

/// Sunrise and sunset at the evaluation location for one day. Either may be missing.
public struct DaySun: Sendable, Codable, Equatable {
    /// Any moment in the day; matched by calendar day.
    public var day: Date
    public var sunrise: Date?
    public var sunset: Date?

    public init(day: Date, sunrise: Date?, sunset: Date?) {
        self.day = day
        self.sunrise = sunrise
        self.sunset = sunset
    }
}

/// When a forecast becomes stale or expires. Ages are measured from the fetch time.
public struct FreshnessPolicy: Sendable, Codable, Equatable {
    public var todayStaleAfter: TimeInterval
    public var todayExpiredAfter: TimeInterval
    public var laterDaysExpiredAfter: TimeInterval

    public init(
        todayStaleAfter: TimeInterval = 3 * 3600, todayExpiredAfter: TimeInterval = 12 * 3600,
        laterDaysExpiredAfter: TimeInterval = 24 * 3600
    ) {
        self.todayStaleAfter = todayStaleAfter
        self.todayExpiredAfter = todayExpiredAfter
        self.laterDaysExpiredAfter = laterDaysExpiredAfter
    }

    /// Today: stale after 3 hours, expired after 12. Later days: expired after 24.
    public static let standard = FreshnessPolicy()
}

/// Everything one evaluation needs. Pure data: the same input always gives the same result.
public struct EvaluationInput: Sendable, Codable, Equatable {
    public var now: Date
    /// Interprets ride windows and days. Its time zone should be the device's.
    public var calendar: Calendar
    public var profile: ProfileSnapshot
    public var samples: [SampleForecast]
    public var alerts: [AlertInfo]
    /// False when the weather source offers no alerts for the area.
    public var alertsAvailable: Bool
    public var sun: [DaySun]
    /// When the forecast was fetched. With several fetch times, pass the oldest.
    public var fetchedAt: Date
    public var freshness: FreshnessPolicy

    public init(
        now: Date, calendar: Calendar, profile: ProfileSnapshot, samples: [SampleForecast],
        alerts: [AlertInfo] = [], alertsAvailable: Bool = true, sun: [DaySun], fetchedAt: Date,
        freshness: FreshnessPolicy = .standard
    ) {
        self.now = now
        self.calendar = calendar
        self.profile = profile
        self.samples = samples
        self.alerts = alerts
        self.alertsAvailable = alertsAvailable
        self.sun = sun
        self.fetchedAt = fetchedAt
        self.freshness = freshness
    }
}
