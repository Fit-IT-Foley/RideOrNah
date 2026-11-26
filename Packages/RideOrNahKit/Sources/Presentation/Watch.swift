import Foundation
import RiderSettings
import VerdictEngine

/// One ride window as the watch receives it.
public struct WatchWindow: Sendable, Codable, Equatable {
    public var start: Date
    public var end: Date
    public var verdict: Verdict
    /// The window's most severe breach, in the iPhone's words and units.
    public var reason: String?

    public init(start: Date, end: Date, verdict: Verdict, reason: String?) {
        self.start = start
        self.end = end
        self.verdict = verdict
        self.reason = reason
    }
}

/// One outlook day as the watch receives it.
public struct WatchDay: Sendable, Codable, Equatable {
    public var day: Date
    public var verdict: Verdict?
    public var summary: String
    public var windows: [WatchWindow]
    public var directionText: String?
    public var lowerConfidence: Bool

    public init(
        day: Date, verdict: Verdict?, summary: String, windows: [WatchWindow], directionText: String?,
        lowerConfidence: Bool
    ) {
        self.day = day
        self.verdict = verdict
        self.summary = summary
        self.windows = windows
        self.directionText = directionText
        self.lowerConfidence = lowerConfidence
    }
}

/// What the iPhone sends the watch: evaluated words and times only, never forecast values, so
/// the watch needs no weather requests of its own.
public struct WatchResults: Sendable, Codable, Equatable {
    public var fetchedAt: Date
    public var hasAccess: Bool
    public var profileName: String
    public var placeName: String
    public var days: [WatchDay]
    /// The Apple Weather mark and legal page, from the iPhone's WeatherKit attribution, so the
    /// watch can show them without asking WeatherKit itself.
    public var attributionMarkURL: URL?
    public var attributionLegalURL: URL?

    public init(
        fetchedAt: Date, hasAccess: Bool, profileName: String, placeName: String, days: [WatchDay],
        attributionMarkURL: URL? = nil, attributionLegalURL: URL? = nil
    ) {
        self.fetchedAt = fetchedAt
        self.hasAccess = hasAccess
        self.profileName = profileName
        self.placeName = placeName
        self.days = days
        self.attributionMarkURL = attributionMarkURL
        self.attributionLegalURL = attributionLegalURL
    }

    /// What the iPhone sends while the rider has no access: no weather at all.
    public static func locked(at date: Date) -> WatchResults {
        WatchResults(fetchedAt: date, hasAccess: false, profileName: "", placeName: "", days: [])
    }

    /// Built on the iPhone from the outlook at the background place, with Today's phrasing.
    public static func make(
        outlook: [DayEvaluation], fetchedAt: Date, hasAccess: Bool, profile: RiderProfile, placeName: String,
        radius: RadiusPreset, formatter: DisplayFormatter
    ) -> WatchResults {
        let outlookPresenter = OutlookPresenter(formatter: formatter)
        let days = outlook.map { day in
            var directionText: String?
            if radius != .local, let verdict = day.verdict, verdict != .ride, verdict != .unknown,
                day.directions != nil
            {
                directionText =
                    day.clearDirections.isEmpty
                    ? "No direction in \(radius.label(in: formatter.units)) is clear"
                    : "Clear to the \(formatter.directionList(day.clearDirections))"
            }
            return WatchDay(
                day: day.day, verdict: day.verdict, summary: outlookPresenter.summary(day, profile: profile),
                windows: day.windows.map {
                    WatchWindow(
                        start: $0.interval.start, end: $0.interval.end, verdict: $0.verdict,
                        reason: $0.breaches.first.map(formatter.summary))
                },
                directionText: directionText, lowerConfidence: day.confidence == .lower)
        }
        return WatchResults(
            fetchedAt: fetchedAt, hasAccess: hasAccess, profileName: profile.name, placeName: placeName, days: days)
    }
}

/// What the watch app and complications show at one moment.
public struct WatchContent: Sendable, Equatable {
    public enum State: Sendable, Equatable {
        case verdict
        /// The results can't call it; no verdict word.
        case unknown
        /// No results, or more than 12 hours old.
        case needsPhone
        case locked
    }

    public struct Window: Sendable, Equatable {
        /// `7–9 AM`
        public var text: String
        public var verdict: Verdict
        public var reason: String?
    }

    public struct Day: Sendable, Equatable {
        public var day: Date
        /// `Thu`
        public var weekday: String
        public var verdict: Verdict?
        public var lowerConfidence: Bool
    }

    public var state: State
    /// `Today` or `Tomorrow`.
    public var label: String
    public var verdict: Verdict?
    public var word: String?
    public var reason: String
    public var windows: [Window]
    public var reasons: [String]
    public var directionText: String?
    public var profileName: String?
    /// Privacy-sensitive.
    public var placeName: String?
    /// `Updated 2 h ago`
    public var age: String?
    /// Older than 3 hours: based on an older forecast.
    public var isStale: Bool
    public var days: [Day]

    static func message(_ state: State, _ reason: String) -> WatchContent {
        WatchContent(
            state: state, label: "Today", verdict: nil, word: nil, reason: reason, windows: [], reasons: [],
            directionText: nil, profileName: nil, placeName: nil, age: nil, isStale: false, days: [])
    }
}

/// The watch's view of the last results it received, for any moment: it follows the day on its
/// own, dropping ended windows and moving past midnight without new results.
public struct WatchPresenter: Sendable {
    public static let staleAfter: TimeInterval = 3 * 3600
    public static let expiredAfter: TimeInterval = 12 * 3600
    public static let openPhone = "Open Ride or Nah on your iPhone."
    public static let subscribe = "Subscribe on your iPhone to see the call."

    public var formatter: DisplayFormatter

    public init(formatter: DisplayFormatter) { self.formatter = formatter }

    public func content(_ results: WatchResults?, now: Date) -> WatchContent {
        guard let results else { return .message(.needsPhone, Self.openPhone) }
        guard results.hasAccess else { return .message(.locked, Self.subscribe) }
        let age = now.timeIntervalSince(results.fetchedAt)
        let calendar = formatter.calendar
        guard age <= Self.expiredAfter,
            let todayIndex = results.days.firstIndex(where: { calendar.isDate($0.day, inSameDayAs: now) })
        else { return .message(.needsPhone, Self.openPhone) }

        var label = "Today"
        var index = todayIndex
        var remaining = results.days[index].windows.filter { $0.end > now }
        if remaining.isEmpty, !results.days[index].windows.isEmpty, index + 1 < results.days.count {
            label = "Tomorrow"
            index += 1
            remaining = results.days[index].windows
        }
        let day = results.days[index]
        let allRemain = remaining.count == day.windows.count
        let verdict = allRemain ? day.verdict : Self.worst(remaining.map(\.verdict))
        var content = WatchContent(
            state: .verdict, label: label, verdict: verdict, word: nil, reason: day.summary,
            windows: remaining.map {
                WatchContent.Window(
                    text: formatter.timeRange(DateInterval(start: $0.start, end: $0.end)), verdict: $0.verdict,
                    reason: $0.reason)
            },
            reasons: Self.unique(remaining.compactMap(\.reason)), directionText: day.directionText,
            profileName: results.profileName, placeName: results.placeName, age: "Updated \(formatter.age(age))",
            isStale: age > Self.staleAfter,
            days: results.days.dropFirst(index + 1).prefix(6).map {
                WatchContent.Day(
                    day: $0.day, weekday: formatter.dayLabel($0.day, now: now).weekday, verdict: $0.verdict,
                    lowerConfidence: $0.lowerConfidence)
            })
        switch verdict {
        case .ride?:
            content.word = VerdictWords.word(.ride)
            if !allRemain { content.reason = "Clear for the rest of your windows" }
        case .maybe?, .nah?:
            content.word = VerdictWords.word(verdict!)
            if !allRemain { content.reason = remaining.first { $0.verdict == verdict }?.reason ?? day.summary }
        case .unknown?, nil:
            content.state = .unknown
            content.verdict = nil
        }
        return content
    }

    /// Nah over Maybe over Can't tell over Ride.
    static func worst(_ verdicts: [Verdict]) -> Verdict? {
        if verdicts.contains(.nah) { return .nah }
        if verdicts.contains(.maybe) { return .maybe }
        if verdicts.contains(.unknown) { return .unknown }
        return verdicts.isEmpty ? nil : .ride
    }

    static func unique(_ strings: [String]) -> [String] {
        var seen = Set<String>()
        return strings.filter { seen.insert($0).inserted }
    }
}

/// When complications change without new results.
public enum WatchTimeline {
    /// Today's window ends still ahead, local midnight, and when the results turn stale (3 h) and
    /// expire (12 h). Sorted, after `now`.
    public static func entryDates(_ results: WatchResults?, now: Date, calendar: Calendar) -> [Date] {
        var dates: [Date] = []
        if let today = results?.days.first(where: { calendar.isDate($0.day, inSameDayAs: now) }) {
            dates += today.windows.map(\.end)
        }
        if let midnight = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) {
            dates.append(midnight)
        }
        if let fetchedAt = results?.fetchedAt {
            dates += [
                fetchedAt.addingTimeInterval(WatchPresenter.staleAfter),
                fetchedAt.addingTimeInterval(WatchPresenter.expiredAfter),
            ]
        }
        return Set(dates.filter { $0 > now }).sorted()
    }
}
