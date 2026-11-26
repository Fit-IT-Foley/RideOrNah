import Foundation

/// A per-device cap on weather requests per local calendar day, shared by the app and its
/// extensions through app-group defaults. Reservation is read-modify-write, so a rare race between
/// processes can overshoot by a few requests; it's a cost guard, not a security boundary.
public struct RequestBudget: Sendable {
    public static let dailyLimit = 150
    static let dayKey = "weather.requestBudget.day"
    static let countKey = "weather.requestBudget.count"

    /// The app-group suite, or nil for the standard defaults (tests, previews).
    public let suiteName: String?
    public let limit: Int

    public init(suiteName: String?, limit: Int = RequestBudget.dailyLimit) {
        self.suiteName = suiteName
        self.limit = limit
    }

    /// Grants up to `count` requests for the local day containing `now`, and records them.
    public func reserve(_ count: Int, now: Date, calendar: Calendar) -> Int {
        let defaults = self.defaults
        let day = Self.dayString(now, calendar: calendar)
        let used = defaults.string(forKey: Self.dayKey) == day ? defaults.integer(forKey: Self.countKey) : 0
        let granted = max(0, min(count, limit - used))
        defaults.set(day, forKey: Self.dayKey)
        defaults.set(used + granted, forKey: Self.countKey)
        return granted
    }

    /// Requests left today.
    public func remaining(now: Date, calendar: Calendar) -> Int {
        let defaults = self.defaults
        let used =
            defaults.string(forKey: Self.dayKey) == Self.dayString(now, calendar: calendar)
            ? defaults.integer(forKey: Self.countKey) : 0
        return max(0, limit - used)
    }

    var defaults: UserDefaults { suiteName.flatMap(UserDefaults.init(suiteName:)) ?? .standard }

    static func dayString(_ date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
}
