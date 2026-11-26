import Foundation
import RiderSettings
import SharedContainer
import Testing
import VerdictEngine

@testable import Presentation
@testable import WeatherData

/// The fixture source, counted, standing in for WeatherKit.
final class CountingProvider: WeatherProviding, @unchecked Sendable {
    let base: FixtureProvider
    private let lock = NSLock()
    private var count = 0
    init(_ base: FixtureProvider) { self.base = base }
    var makesNetworkRequests: Bool { true }
    var calls: Int { lock.withLock { count } }
    func forecast(at coordinate: RoundedCoordinate, hours: DateInterval, days: DateInterval)
        async throws(WeatherSourceError) -> PointForecast
    {
        lock.withLock { count += 1 }
        return try await base.forecast(at: coordinate, hours: hours, days: days)
    }
}

struct WidgetTests {
    static func presenter(_ scene: Scene) -> WidgetPresenter { WidgetPresenter(formatter: scene.formatter) }

    static func content(_ scene: Scene, hasAccess: Bool = true) -> WidgetContent {
        presenter(scene).content(
            outlook: scene.outlook, fetchedAt: scene.fetchedAt ?? scene.now, place: "Home", profile: scene.profile,
            hasAccess: hasAccess, now: scene.now)
    }

    // Scenario: widgets: Medium widget
    @Test("Medium widget")
    func mediumWidget() {
        let content = Self.content(Scene())
        #expect(content.state == .verdict)
        #expect(content.label == "Today")
        #expect(content.word == "RIDE")
        #expect(content.reason == "All clear")
        #expect(content.age == "Updated just now")
        #expect(content.days.map(\.weekday) == ["Tue", "Wed", "Thu"])
        #expect(content.days.map(\.word) == ["RIDE", "RIDE", "RIDE"])
        #expect(content.days.map(\.lowerConfidence) == [false, false, true])
    }

    // Scenario: widgets: Evening
    @Test("Evening")
    func evening() {
        var scene = Scene()
        scene.now = Scene.at(18, 30)
        scene.fetchedAt = Scene.at(18)
        let content = Self.content(scene)
        #expect(content.label == "Tomorrow")
        #expect(content.word == "RIDE")
        #expect(content.days.first?.weekday == "Wed")
    }

    // Scenario: widgets: Old data
    @Test("Old data")
    func oldData() {
        var scene = Scene()
        scene.profile = RiderProfile.defaults(named: "Anytime", style: .anytime)
        scene.fetchedAt = Scene.at(day: -1, 17)
        scene.now = Scene.at(7)
        let content = Self.content(scene)
        #expect(content.state == .unknown)
        #expect(content.word == nil)
        #expect(content.reason == WidgetPresenter.tooOldReason)
    }

    // Scenario: widgets: Lapsed subscription
    @Test("Lapsed subscription")
    func lapsedSubscription() {
        let content = Self.content(Scene(), hasAccess: false)
        #expect(content.state == .locked)
        #expect(content.word == nil)
        #expect(content.reason == "Subscribe to see today's call.")
        #expect(content.age == nil)
        #expect(content.place == nil)
        #expect(content.days.isEmpty)
    }

    // Scenario: widgets: Data ages without a refresh
    @Test("Data ages without a refresh")
    func dataAgesWithoutARefresh() {
        var scene = Scene()
        scene.profile = RiderProfile.defaults(named: "Anytime", style: .anytime)
        let fetched = Scene.at(6)
        let dates = WidgetTimeline.entryDates(
            outlook: scene.outlook, fetchedAt: fetched, now: fetched, calendar: Scene.calendar)
        #expect(dates.contains(Scene.at(9)))
        #expect(dates.contains(Scene.at(18)))
        #expect(dates.contains(Scene.at(day: 1, 0)))
        func at(_ date: Date) -> WidgetContent {
            var later = scene
            later.now = date
            later.fetchedAt = fetched
            return Self.content(later)
        }
        #expect(at(Scene.at(8)).isStale == false)
        #expect(at(Scene.at(9, 1)).isStale)
        #expect(at(Scene.at(9, 1)).word == "RIDE")
        #expect(at(Scene.at(18, 1)).word == nil)
        #expect(at(Scene.at(18, 1)).state == .unknown)
    }

    @Test("Window ends are timeline entries")
    func windowEnds() {
        let scene = Scene()
        let dates = WidgetTimeline.entryDates(
            outlook: scene.outlook, fetchedAt: scene.now, now: scene.now, calendar: Scene.calendar)
        #expect(dates.contains(Scene.at(9)))
        #expect(dates.contains(Scene.at(18)))
        #expect(dates == dates.sorted())
    }

    @Test("Links")
    func links() {
        let thursday = Scene.at(day: 3, 0)
        let url = RideURL.day(thursday).url(calendar: Scene.calendar)
        #expect(url.absoluteString == "rideornah://day/2026-06-11")
        #expect(RideURL(url, calendar: Scene.calendar) == .day(thursday))
        #expect(RideURL(URL(string: "rideornah://today")!, calendar: Scene.calendar) == .today)
        #expect(RideURL(URL(string: "https://example.com")!, calendar: Scene.calendar) == nil)
        #expect(Self.content(Scene()).days[2].url == url)
    }
}

/// The loader as the widget extension runs it, against the app's cache and settings.
struct WidgetLoaderTests {
    static let home = GeoCoordinate(latitude: 40.71, longitude: -74.01)
    static let now = Scene.at(6)

    static func setUp(scenario: FixtureProvider.Scenario) -> (
        store: PreferencesStore, container: SharedContainer, cache: ForecastCache, provider: CountingProvider
    ) {
        let directory = FileManager.default.temporaryDirectory.appending(path: "Widget-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let container = SharedContainer.resolve(groupIdentifier: "test") { _ in directory }
        container.writeAccessMirror(AccessMirror(isActive: true, checkedAt: now))
        let store = PreferencesStore(defaults: UserDefaults(suiteName: "widget-\(UUID().uuidString)")!, cloud: nil)
        var preferences = Preferences(firstProfile: RiderProfile.defaults(named: "My Bike", style: .commute))
        preferences.unitPreference = .imperial
        store.save(preferences)
        store.lastSeenLocation = home
        let cache = ForecastCache(directory: directory.appending(path: "cache"))
        let provider = CountingProvider(FixtureProvider(scenario: scenario, center: home, calendar: Scene.calendar))
        return (store, container, cache, provider)
    }

    static func loader(
        _ setup: (store: PreferencesStore, container: SharedContainer, cache: ForecastCache, provider: CountingProvider)
    ) -> WidgetLoader {
        let provider = setup.provider
        return WidgetLoader(
            store: setup.store, container: setup.container, cache: setup.cache, budget: nil,
            provider: { _ in provider }, calendar: Scene.calendar, clock: { now })
    }

    /// What the app fetches and shows, at the same place and radius.
    static func appOutlook(
        _ setup: (store: PreferencesStore, container: SharedContainer, cache: ForecastCache, provider: CountingProvider)
    ) async -> [DayEvaluation]? {
        let preferences = setup.store.load()!
        let store = ForecastStore(
            provider: setup.provider, cache: setup.cache, budget: nil, calendar: Scene.calendar, clock: { now })
        let snapshot = await store.snapshot(
            center: home, radius: preferences.radius(on: now, calendar: Scene.calendar).metres, purpose: .foreground)
        return snapshot.evaluationInput(profile: preferences.activeProfile.snapshot, now: now, calendar: Scene.calendar)
            .map(VerdictEngine.outlook)
    }

    // Scenario: widgets: Matching verdicts
    @Test("Matching verdicts", arguments: FixtureProvider.Scenario.allCases)
    func matchingVerdicts(scenario: FixtureProvider.Scenario) async {
        let setup = Self.setUp(scenario: scenario)
        let app = await Self.appOutlook(setup)?.first?.verdict
        let widget = await Self.loader(setup).timeline().entries.first?.content
        #expect(widget?.verdict == (app == .unknown ? nil : app))
    }

    // Scenario: widgets: After opening the app
    @Test("After opening the app")
    func afterOpeningTheApp() async {
        let setup = Self.setUp(scenario: .afternoonRain)
        _ = await Self.appOutlook(setup)
        let fetched = setup.provider.calls
        #expect(fetched > 0)
        let (entries, snapshot) = await Self.loader(setup).timeline()
        #expect(setup.provider.calls == fetched)
        #expect(snapshot?.networkRequests == 0)
        #expect(entries.first?.content.word == "NAH")
        #expect(entries.first?.content.place == "Where I last opened the app")
    }

    @Test("Locked and not set up need no forecast")
    func lockedAndNotSetUp() async {
        let setup = Self.setUp(scenario: .clearDay)
        setup.container.writeAccessMirror(AccessMirror(isActive: false, checkedAt: Self.now))
        let (entries, snapshot) = await Self.loader(setup).timeline()
        #expect(entries.map(\.content.state) == [.locked])
        #expect(snapshot == nil)
        #expect(setup.provider.calls == 0)
    }
}
