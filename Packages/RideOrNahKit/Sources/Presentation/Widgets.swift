import Foundation
import RiderSettings
import SharedContainer
import VerdictEngine
import WeatherData

/// Links into the app, for widget taps: `rideornah://today` and `rideornah://day/2026-06-11`.
public enum RideURL: Equatable, Sendable {
    case today
    case day(Date)

    public static let scheme = "rideornah"

    public func url(calendar: Calendar) -> URL {
        switch self {
        case .today: return URL(string: "\(Self.scheme)://today")!
        case .day(let day): return URL(string: "\(Self.scheme)://day/\(Self.key(day, calendar: calendar))")!
        }
    }

    /// Where a link goes, or nil when it isn't ours.
    public init?(_ url: URL, calendar: Calendar) {
        guard url.scheme == Self.scheme else { return nil }
        switch url.host() {
        case "today":
            self = .today
        case "day":
            let parts = url.lastPathComponent.split(separator: "-").compactMap { Int($0) }
            guard parts.count == 3,
                let day = calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
            else { return nil }
            self = .day(day)
        default:
            return nil
        }
    }

    static func key(_ day: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: day)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
}

/// One of the next three days in the medium widget.
public struct WidgetDay: Sendable, Equatable {
    public var day: Date
    /// `Thu`
    public var weekday: String
    public var verdict: Verdict?
    /// `RIDE`, or `–` when it can't be called.
    public var word: String
    public var lowerConfidence: Bool
    public var url: URL
}

/// What a widget shows at one moment.
public struct WidgetContent: Sendable, Equatable {
    public enum State: Sendable, Equatable {
        case verdict
        /// The forecast can't call it; no verdict word.
        case unknown
        /// No subscription; no weather at all.
        case locked
        /// Not set up yet, or no place to check.
        case needsApp
    }

    public var state: State
    /// `Today` or `Tomorrow`.
    public var label: String
    public var verdict: Verdict?
    /// `RIDE`, `MAYBE` or `NAH`; nil without a verdict.
    public var word: String?
    /// `All clear`, the main reason, or what to do.
    public var reason: String
    /// `Updated 12 min ago`
    public var age: String?
    /// Older than 3 hours.
    public var isStale: Bool
    /// Privacy-sensitive: hidden on a locked device.
    public var place: String?
    public var days: [WidgetDay]
    public var url: URL

    /// What the widget gallery and loading state show.
    public static func placeholder(calendar: Calendar) -> WidgetContent {
        let today = calendar.startOfDay(for: Date())
        let days = (1...3).map { offset in
            let day = calendar.date(byAdding: .day, value: offset, to: today)!
            return WidgetDay(
                day: day, weekday: DisplayFormatter.weekdays[calendar.component(.weekday, from: day) - 1],
                verdict: .ride, word: "RIDE", lowerConfidence: offset == 3,
                url: RideURL.day(day).url(calendar: calendar))
        }
        return WidgetContent(
            state: .verdict, label: "Today", verdict: .ride, word: "RIDE", reason: "All clear",
            age: "Updated just now", isStale: false, place: nil, days: days, url: RideURL.today.url(calendar: calendar))
    }

    public static func message(_ state: State, _ reason: String, calendar: Calendar) -> WidgetContent {
        WidgetContent(
            state: state, label: "Today", verdict: nil, word: nil, reason: reason, age: nil, isStale: false,
            place: nil, days: [], url: RideURL.today.url(calendar: calendar))
    }
}

/// Widget content from the engine's outlook, with the same rules as the app.
public struct WidgetPresenter: Sendable {
    public static let lockedReason = "Subscribe to see today's call."
    public static let tooOldReason = "Forecast too old. Open Ride or Nah."

    public var formatter: DisplayFormatter

    public init(formatter: DisplayFormatter) { self.formatter = formatter }

    public func content(
        outlook: [DayEvaluation]?, fetchedAt: Date?, place: String?, profile: RiderProfile, hasAccess: Bool, now: Date
    ) -> WidgetContent {
        let calendar = formatter.calendar
        guard hasAccess else { return .message(.locked, Self.lockedReason, calendar: calendar) }
        guard let outlook, var today = outlook.first, let fetchedAt else {
            return .message(.needsApp, "Open Ride or Nah to get today's forecast.", calendar: calendar)
        }
        var label = "Today"
        var rest = Array(outlook.dropFirst())
        if today.status != .evaluated, outlook.count > 1 {
            today = outlook[1]
            label = "Tomorrow"
            rest = Array(outlook.dropFirst(2))
        }
        let age = now.timeIntervalSince(fetchedAt)
        var content = WidgetContent(
            state: .verdict, label: label, verdict: today.verdict, word: nil, reason: "",
            age: "Updated \(formatter.age(age))",
            isStale: age > SuggestionPresenter.freshFor, place: place,
            days: rest.prefix(3).map { day($0, now: now) }, url: RideURL.today.url(calendar: calendar))
        switch today.verdict {
        case .ride?:
            content.word = VerdictWords.word(.ride)
            content.reason = "All clear"
        case .maybe?, .nah?:
            content.word = VerdictWords.word(today.verdict!)
            content.reason = today.breaches.first.map(formatter.summary) ?? ""
        case .unknown?, nil:
            content.state = .unknown
            content.verdict = nil
            content.reason =
                today.unknownReason == .forecastTooOld ? Self.tooOldReason : "Forecast missing. Open Ride or Nah."
        }
        return content
    }

    func day(_ day: DayEvaluation, now: Date) -> WidgetDay {
        let callable = day.verdict.map { $0 != .unknown } ?? false
        return WidgetDay(
            day: day.day, weekday: formatter.dayLabel(day.day, now: now).weekday,
            verdict: callable ? day.verdict : nil, word: callable ? VerdictWords.word(day.verdict!) : "–",
            lowerConfidence: day.confidence == .lower, url: RideURL.day(day.day).url(calendar: formatter.calendar))
    }
}

/// When a widget's content changes without new data.
public enum WidgetTimeline {
    public static let staleAfter: TimeInterval = 3 * 3600
    public static let expiredAfter: TimeInterval = 12 * 3600

    /// Today's window ends still ahead, local midnight, and when the forecast turns stale and
    /// expires. Sorted, after `now`.
    public static func entryDates(outlook: [DayEvaluation]?, fetchedAt: Date?, now: Date, calendar: Calendar) -> [Date]
    {
        var dates: [Date] = []
        if let today = outlook?.first { dates += today.windows.map(\.interval.end) }
        if let midnight = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) {
            dates.append(midnight)
        }
        if let fetchedAt {
            dates += [fetchedAt.addingTimeInterval(staleAfter), fetchedAt.addingTimeInterval(expiredAfter)]
        }
        return Set(dates.filter { $0 > now }).sorted()
    }
}

/// What the widget extension does for each timeline: reads the app's settings, access and
/// cached forecasts, fetches only under the widget rules, and evaluates at each entry date.
public struct WidgetLoader {
    public struct Entry: Sendable, Equatable {
        public var date: Date
        public var content: WidgetContent
    }

    public var store: PreferencesStore
    public var container: SharedContainer
    public var cache: ForecastCache
    public var budget: RequestBudget?
    public var provider: @Sendable (GeoCoordinate) -> any WeatherProviding
    public var calendar: Calendar
    public var clock: @Sendable () -> Date

    public init(
        store: PreferencesStore, container: SharedContainer, cache: ForecastCache, budget: RequestBudget?,
        provider: @escaping @Sendable (GeoCoordinate) -> any WeatherProviding, calendar: Calendar,
        clock: @escaping @Sendable () -> Date
    ) {
        self.store = store
        self.container = container
        self.cache = cache
        self.budget = budget
        self.provider = provider
        self.calendar = calendar
        self.clock = clock
    }

    /// The entries, now first, and the snapshot they came from (nil without a fetch attempt).
    public func timeline() async -> (entries: [Entry], snapshot: ForecastSnapshot?) {
        let now = clock()
        guard let preferences = store.load() else {
            return (
                [Entry(date: now, content: .message(.needsApp, "Open Ride or Nah to set up.", calendar: calendar))], nil
            )
        }
        let formatter = DisplayFormatter(units: preferences.unitPreference.resolved(), calendar: calendar)
        let presenter = WidgetPresenter(formatter: formatter)
        guard container.readAccessMirror()?.isActive == true else {
            return (
                [Entry(date: now, content: .message(.locked, WidgetPresenter.lockedReason, calendar: calendar))], nil
            )
        }
        guard let place = preferences.backgroundPlace(lastSeen: store.lastSeenLocation) else {
            return (
                [
                    Entry(
                        date: now,
                        content: .message(.needsApp, "Open Ride or Nah to set your place.", calendar: calendar))
                ],
                nil
            )
        }
        let forecastStore = ForecastStore(
            provider: provider(place.coordinate), cache: cache, budget: budget, calendar: calendar, clock: clock)
        let snapshot = await forecastStore.snapshot(
            center: place.coordinate, radius: preferences.radius(on: now, calendar: calendar).metres, purpose: .widget)
        let profile = preferences.activeProfile
        func evaluate(at date: Date) -> [DayEvaluation]? {
            snapshot.evaluationInput(profile: profile.snapshot, now: date, calendar: calendar).map(
                VerdictEngine.outlook)
        }
        let dates =
            [now]
            + WidgetTimeline.entryDates(
                outlook: evaluate(at: now), fetchedAt: snapshot.fetchedAt, now: now, calendar: calendar)
        let entries = dates.map { date in
            Entry(
                date: date,
                content: presenter.content(
                    outlook: evaluate(at: date), fetchedAt: snapshot.fetchedAt, place: place.name, profile: profile,
                    hasAccess: true, now: date))
        }
        return (entries, snapshot)
    }
}
