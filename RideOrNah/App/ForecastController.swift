import Foundation
import Observation
import Presentation
import RiderSettings
import SharedContainer
import VerdictEngine
import WeatherData

/// Fetches forecasts for the rider's place and radius, evaluates them with the active profile,
/// and keeps the result current: on appear, on pull to refresh, when choices change, at midnight.
@Observable
final class ForecastController {
    enum Source: Equatable {
        case live
        #if DEBUG
            case fixture(FixtureProvider.Scenario)
        #endif
    }

    private(set) var snapshot: ForecastSnapshot?
    private(set) var outlook: [DayEvaluation]?
    private(set) var place: ResolvedLocation?
    private(set) var isRefreshing = false
    /// A short message such as "Already up to date", cleared on the next refresh.
    private(set) var message: String?
    private(set) var attribution = WeatherAttributionInfo.fixture

    let app: AppModel
    let source: Source
    let clock: @Sendable () -> Date
    private let cache: ForecastCache
    private let budget: RequestBudget?

    init(
        app: AppModel, source: Source, clock: @escaping @Sendable () -> Date, cache: ForecastCache,
        budget: RequestBudget?
    ) {
        self.app = app
        self.source = source
        self.clock = clock
        self.cache = cache
        self.budget = budget
        NotificationCenter.default.addObserver(forName: .NSCalendarDayChanged, object: nil, queue: .main) {
            [weak self] _ in
            MainActor.assumeIsolated { self?.handleDayChange() }
        }
    }

    /// The live controller, or, in debug builds, fixture weather and a fixed clock from launch
    /// arguments (`-weatherSource fixture -weatherScenario <name> -fixedNow 2026-06-08T06:00`).
    static func live(app: AppModel) -> ForecastController {
        var source = Source.live
        var clock: @Sendable () -> Date = { Date() }
        let container = SharedContainer.current()
        var cache = ForecastCache(container: container)
        let group = Bundle.main.object(forInfoDictionaryKey: SharedContainer.infoPlistKey) as? String
        #if DEBUG
            let arguments = UserDefaults.standard
            if arguments.string(forKey: "weatherSource") == "fixture" {
                let scenario = arguments.string(forKey: "weatherScenario").flatMap(
                    FixtureProvider.Scenario.init(rawValue:))
                source = .fixture(scenario ?? .clearDay)
                cache = ForecastCache(
                    directory: FileManager.default.temporaryDirectory.appending(path: "Fixture-\(UUID().uuidString)"))
            }
            if let text = arguments.string(forKey: "fixedNow"), let fixed = Self.parseLocal(text) {
                clock = { fixed }
            }
        #endif
        return ForecastController(
            app: app, source: source, clock: clock, cache: cache, budget: RequestBudget(suiteName: group))
    }

    static func parseLocal(_ text: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
        return formatter.date(from: text)
    }

    var calendar: Calendar { Calendar.current }

    var formatter: DisplayFormatter {
        DisplayFormatter(units: app.preferences?.unitPreference.resolved() ?? .imperial, calendar: calendar)
    }

    var today: TodayContent? {
        guard let preferences = app.preferences else { return nil }
        return TodayPresenter(formatter: formatter).content(
            outlook: outlook, snapshot: snapshot, place: place, profile: preferences.activeProfile,
            radius: preferences.radius(on: clock(), calendar: calendar), now: clock())
    }

    var outlookRows: [OutlookRow] {
        guard let preferences = app.preferences, let outlook else { return [] }
        return OutlookPresenter(formatter: formatter).rows(outlook, profile: preferences.activeProfile, now: clock())
    }

    func detail(for day: Date) -> DayDetailContent? {
        guard let preferences = app.preferences,
            let evaluation = outlook?.first(where: { calendar.isDate($0.day, inSameDayAs: day) })
        else { return nil }
        return DayDetailPresenter(formatter: formatter).content(
            evaluation, snapshot: snapshot, profile: preferences.activeProfile, now: clock())
    }

    // MARK: Refreshing

    /// Fetches what's needed for `purpose` (cached data is reused within its interval) and evaluates.
    func refresh(_ purpose: RefreshPurpose) async {
        guard let preferences = app.preferences else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        message = nil
        let reading = await app.location.currentReading()
        if let reading { app.store.lastSeenLocation = reading.coordinate }
        place = preferences.evaluationPlace(current: reading)
        guard let place else {
            snapshot = nil
            outlook = nil
            return
        }
        let now = clock()
        let radius = preferences.radius(on: now, calendar: calendar)
        let store = ForecastStore(
            provider: provider(center: place.coordinate), cache: cache,
            budget: isLive ? budget : nil, calendar: calendar, clock: clock)
        let snapshot = await store.snapshot(center: place.coordinate, radius: radius.metres, purpose: purpose)
        if snapshot.outcome == .alreadyCurrent { message = "Already up to date" }
        self.snapshot = snapshot
        evaluate()
        if purpose != .background { await onRefreshed?() }
        if isLive, attribution == .fixture, let live = try? await WeatherAttributionInfo.live() { attribution = live }
    }

    /// Called after each foreground or manual refresh, so notifications can be rebuilt.
    var onRefreshed: (() async -> Void)?

    /// The outlook at the background location source (for notifications), with today's radius,
    /// from cache where possible. Nil when there's no background place.
    func backgroundEvaluation() async -> (outlook: [DayEvaluation]?, fetchedAt: Date?)? {
        guard let preferences = app.preferences,
            let place = preferences.backgroundPlace(lastSeen: app.store.lastSeenLocation)
        else { return nil }
        let now = clock()
        let store = ForecastStore(
            provider: provider(center: place.coordinate), cache: cache, budget: isLive ? budget : nil,
            calendar: calendar, clock: clock)
        let snapshot = await store.snapshot(
            center: place.coordinate, radius: preferences.radius(on: now, calendar: calendar).metres,
            purpose: .background)
        let outlook = snapshot.evaluationInput(
            profile: preferences.activeProfile.snapshot, now: now, calendar: calendar
        )
        .map(VerdictEngine.outlook(for:))
        return (outlook, snapshot.fetchedAt)
    }

    /// Re-evaluates the snapshot already in hand, for profile changes that need no new data.
    func evaluate() {
        guard let preferences = app.preferences, let snapshot else {
            outlook = nil
            return
        }
        let now = clock()
        outlook = snapshot.evaluationInput(profile: preferences.activeProfile.snapshot, now: now, calendar: calendar)
            .map(VerdictEngine.outlook(for:))
    }

    /// At midnight: clear yesterday's radius override and evaluate the new day.
    func handleDayChange() {
        app.update { $0.clearExpiredOverrides(now: clock(), calendar: calendar) }
        evaluate()
    }

    var isLive: Bool { source == .live }

    private func provider(center: GeoCoordinate) -> any WeatherProviding {
        switch source {
        case .live: return WeatherKitProvider()
        #if DEBUG
            case .fixture(let scenario): return FixtureProvider(scenario: scenario, center: center, calendar: calendar)
        #endif
        }
    }
}
