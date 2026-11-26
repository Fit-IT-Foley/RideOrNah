import Foundation

/// One limit crossed over a stretch of consecutive hours.
public struct Breach: Sendable, Codable, Equatable {
    public var factor: Factor
    public var severity: Severity
    /// The worst forecast value in the stretch (highest, or lowest for cold and visibility). Nil
    /// for breaches without a measured value, such as storms, alerts and wet roads.
    public var worstValue: Double?
    /// The limit that was crossed, in the same units as `worstValue`.
    public var limit: Double?
    /// From the start of the first breached hour to the end of the last.
    public var range: DateInterval
    /// Where it happens, sorted. `.center` is the evaluation location.
    public var positions: [SamplePosition]
    /// The alert's name, for alert breaches.
    public var alertName: String?

    public var directions: [CompassDirection] {
        Array(Set(positions.compactMap(\.direction))).sorted()
    }
}

public enum Coverage: Sendable, Codable, Equatable {
    case full
    /// Some directions had no data; they're listed in order.
    case partial(missing: [CompassDirection])
}

public enum Freshness: Sendable, Codable, Equatable {
    case fresh
    /// Usable, but older than the stale threshold.
    case stale(age: TimeInterval)
    /// Too old to use; the verdict is Unknown.
    case expired(age: TimeInterval)
}

public enum UnknownReason: String, Sendable, Codable {
    case forecastTooOld
    case missingData
    case missingSunTimes
}

public enum Confidence: String, Sendable, Codable {
    case normal, lower
}

public enum DayStatus: String, Sendable, Codable {
    /// The day has a verdict.
    case evaluated
    /// Every ride window today has ended.
    case noRideWindowsRemaining
    /// A day without windows, after sunset.
    case noDaylightRemaining
}

public struct DirectionVerdict: Sendable, Codable, Equatable {
    public var direction: CompassDirection
    public var verdict: Verdict
}

public struct WindowEvaluation: Sendable, Codable, Equatable {
    /// The ride window, or sunrise to sunset on a day without windows.
    public var interval: DateInterval
    public var evaluatedHours: [Date]
    public var verdict: Verdict
    public var unknownReason: UnknownReason?
    /// Today only: the window has already ended and doesn't count toward the day verdict.
    public var isEnded: Bool
    public var breaches: [Breach]
}

public struct DayEvaluation: Sendable, Codable, Equatable {
    /// Start of the day.
    public var day: Date
    public var status: DayStatus
    /// Nil when `status` says nothing is left to evaluate today.
    public var verdict: Verdict?
    public var unknownReason: UnknownReason?
    /// The profile has no window on this weekday, so daylight hours were evaluated.
    public var hasNoScheduledWindow: Bool
    public var windows: [WindowEvaluation]
    /// Every breach in the windows still counted, most severe first, then by start time.
    public var breaches: [Breach]
    /// Nil for a local radius (no ring points).
    public var directions: [DirectionVerdict]?
    public var clearDirections: [CompassDirection]
    public var coverage: Coverage
    public var freshness: Freshness
    public var confidence: Confidence
    /// Daylight stretches worth riding, longest first, at most three.
    public var opportunities: [DateInterval]
    /// Factors that had no data to check.
    public var notChecked: [Factor]
    /// Factors checked with only part of the data they need, such as wet roads without lookback.
    public var partiallyChecked: [Factor]
}

public struct RangeEvaluation: Sendable, Codable, Equatable {
    public var range: DateInterval
    public var verdict: Verdict
    public var unknownReason: UnknownReason?
    public var breaches: [Breach]
    public var coverage: Coverage
    public var notChecked: [Factor]
    public var partiallyChecked: [Factor]
}
