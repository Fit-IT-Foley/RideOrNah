import Foundation
import Testing
import VerdictEngine

@testable import WeatherData

/// Cache, budget and refresh decisions, with exact request counts.
struct StoreTests {
    // Scenario: weather-data: Reopening the app
    @Test("Reopening the app")
    func reopeningTheApp() async {
        let harness = StoreHarness()
        defer { harness.tearDown() }
        await harness.seedCache(age: 40 * 60)
        let snapshot = await harness.store().snapshot(center: TestTime.newYork, radius: 40_000, purpose: .foreground)
        #expect(harness.provider.requestCount == 0)
        #expect(snapshot.networkRequests == 0)
        #expect(snapshot.outcome == .complete)
        #expect(snapshot.samples.allSatisfy { !$0.hours.isEmpty })
    }

    // Scenario: weather-data: Pull to refresh too soon
    @Test("Pull to refresh too soon")
    func pullToRefreshTooSoon() async {
        let harness = StoreHarness()
        defer { harness.tearDown() }
        await harness.seedCache(age: 10 * 60)
        let snapshot = await harness.store().snapshot(center: TestTime.newYork, radius: 40_000, purpose: .manual)
        #expect(harness.provider.requestCount == 0)
        #expect(snapshot.outcome == .alreadyCurrent)
    }

    @Test func manualRefreshAfter15MinutesFetches() async {
        let harness = StoreHarness()
        defer { harness.tearDown() }
        await harness.seedCache(age: 16 * 60)
        let snapshot = await harness.store().snapshot(center: TestTime.newYork, radius: 40_000, purpose: .manual)
        #expect(harness.provider.requestCount == 9)
        #expect(snapshot.outcome == .complete)
    }

    // Scenario: weather-data: Widget refresh
    @Test("Widget refresh")
    func widgetRefresh() async {
        let harness = StoreHarness()
        defer { harness.tearDown() }
        await harness.seedCache(age: 90 * 60)
        _ = await harness.store().snapshot(center: TestTime.newYork, radius: 40_000, purpose: .widget)
        #expect(harness.provider.requestCount == 0)
    }

    @Test func emptyCacheFetchesEveryPointOnce() async {
        let harness = StoreHarness()
        defer { harness.tearDown() }
        let snapshot = await harness.store().snapshot(center: TestTime.newYork, radius: 160_000, purpose: .foreground)
        #expect(harness.provider.requestCount == 17)
        #expect(snapshot.networkRequests == 17)
        #expect(harness.budget.remaining(now: harness.clock.now, calendar: TestTime.calendar) == 150 - 17)
        #expect(harness.provider.peakConcurrency <= 4)
    }

    // Scenario: weather-data: Budget exhausted
    @Test("Budget exhausted")
    func budgetExhausted() async {
        let harness = StoreHarness()
        defer { harness.tearDown() }
        await harness.seedCache(age: 3 * 3600)
        _ = harness.budget.reserve(150, now: harness.clock.now, calendar: TestTime.calendar)
        let snapshot = await harness.store().snapshot(center: TestTime.newYork, radius: 40_000, purpose: .foreground)
        #expect(harness.provider.requestCount == 0)
        #expect(snapshot.outcome == .budgetLimited)
        #expect(snapshot.fetchedAt == harness.clock.now.addingTimeInterval(-3 * 3600))
    }

    @Test func partlyCoveredBudgetFetchesTheCenterFirst() async {
        let harness = StoreHarness()
        defer { harness.tearDown() }
        _ = harness.budget.reserve(147, now: harness.clock.now, calendar: TestTime.calendar)
        let snapshot = await harness.store().snapshot(center: TestTime.newYork, radius: 40_000, purpose: .foreground)
        #expect(harness.provider.requestCount == 3)
        #expect(snapshot.outcome == .budgetLimited)
        #expect(!snapshot.samples[0].hours.isEmpty)
    }

    // Scenario: weather-data: New day
    @Test("New day")
    func newDay() {
        let harness = StoreHarness()
        defer { harness.tearDown() }
        let today = harness.clock.now
        #expect(harness.budget.reserve(200, now: today, calendar: TestTime.calendar) == 150)
        let tomorrow = TestTime.calendar.date(byAdding: .day, value: 1, to: today)!
        #expect(harness.budget.remaining(now: tomorrow, calendar: TestTime.calendar) == 150)
        #expect(harness.budget.reserve(1, now: tomorrow, calendar: TestTime.calendar) == 1)
    }

    @Test func budgetResetsAcrossASpringForwardNight() {
        let harness = StoreHarness()
        defer { harness.tearDown() }
        let saturday = TestTime.calendar.date(from: DateComponents(year: 2026, month: 3, day: 7, hour: 23, minute: 30))!
        _ = harness.budget.reserve(150, now: saturday, calendar: TestTime.calendar)
        // 01:30 on the 23-hour Sunday is a new local day.
        #expect(
            harness.budget.remaining(now: saturday.addingTimeInterval(2 * 3600), calendar: TestTime.calendar) == 150)
    }

    // Scenario: weather-data: Widget after app refresh
    @Test("Widget after app refresh")
    func widgetAfterAppRefresh() async {
        let harness = StoreHarness()
        defer { harness.tearDown() }
        _ = await harness.store().snapshot(center: TestTime.newYork, radius: 40_000, purpose: .foreground)
        #expect(harness.provider.requestCount == 9)

        harness.clock.advance(5 * 60)
        let widgetProvider = RecordingProvider()
        let widget = ForecastStore(
            provider: widgetProvider, cache: ForecastCache(directory: harness.directory), budget: harness.budget,
            calendar: TestTime.calendar, clock: harness.clock.function)
        let snapshot = await widget.snapshot(center: TestTime.newYork, radius: 40_000, purpose: .widget)
        #expect(widgetProvider.requestCount == 0)
        #expect(snapshot.samples.allSatisfy { !$0.hours.isEmpty })
    }

    // Scenario: weather-data: Old cache entries
    @Test("Old cache entries")
    func oldCacheEntries() async {
        let harness = StoreHarness()
        defer { harness.tearDown() }
        await harness.seedCache(age: 49 * 3600)
        let center = harness.points()[0].coordinate
        #expect(await harness.cache.read(center) != nil)
        harness.provider.failEverything = .offline
        _ = await harness.store().snapshot(center: TestTime.newYork, radius: 40_000, purpose: .foreground)
        #expect(await harness.cache.read(center) == nil)
    }

    @Test func cacheLivesInTheContainersCachesDirectory() {
        let cache = ForecastCache(container: .resolve(groupIdentifier: nil))
        #expect(cache.directory.path().hasSuffix("Library/Caches/Forecasts/"))
    }

    // Scenario: weather-data: Offline with cache
    @Test("Offline with cache")
    func offlineWithCache() async {
        let harness = StoreHarness()
        defer { harness.tearDown() }
        await harness.seedCache(age: 4 * 3600)
        harness.provider.failEverything = .offline
        let snapshot = await harness.store().snapshot(center: TestTime.newYork, radius: 40_000, purpose: .foreground)
        #expect(snapshot.outcome == .offline)
        #expect(snapshot.fetchedAt == harness.clock.now.addingTimeInterval(-4 * 3600))
        #expect(snapshot.samples.allSatisfy { !$0.hours.isEmpty })
    }

    // Scenario: weather-data: Offline without cache
    @Test("Offline without cache")
    func offlineWithoutCache() async {
        let harness = StoreHarness()
        defer { harness.tearDown() }
        harness.provider.failEverything = .offline
        let snapshot = await harness.store().snapshot(center: TestTime.newYork, radius: 40_000, purpose: .foreground)
        #expect(snapshot.outcome == .offline)
        #expect(snapshot.fetchedAt == nil)
        #expect(snapshot.samples.allSatisfy { $0.hours.isEmpty })
        let profile = ProfileSnapshot(limits: Limits(), windows: [])
        #expect(snapshot.evaluationInput(profile: profile, now: harness.clock.now, calendar: TestTime.calendar) == nil)
    }

    @Test func authorizationFailureIsReportedAsSuch() async {
        let harness = StoreHarness()
        defer { harness.tearDown() }
        harness.provider.failEverything = .notAuthorized
        let snapshot = await harness.store().snapshot(center: TestTime.newYork, radius: 0, purpose: .foreground)
        #expect(snapshot.outcome == .notAuthorized)
    }

    // Scenario: weather-data: Some ring points fail
    @Test("Some ring points fail")
    func someRingPointsFail() async {
        let harness = StoreHarness()
        defer { harness.tearDown() }
        let points = harness.points()
        let failed = points.filter { [.ring(.sw, .outer), .ring(.w, .outer)].contains($0.position) }
        harness.provider.failing = Dictionary(uniqueKeysWithValues: failed.map { ($0.coordinate, .serviceUnavailable) })
        let snapshot = await harness.store().snapshot(center: TestTime.newYork, radius: 40_000, purpose: .foreground)
        #expect(snapshot.outcome == .partial(failed: [.ring(.sw, .outer), .ring(.w, .outer)]))
        #expect(
            snapshot.samples.filter { $0.hours.isEmpty }.map(\.position) == [.ring(.sw, .outer), .ring(.w, .outer)])
    }

    // Scenario: weather-data: Lookback for wet roads
    @Test("Lookback for wet roads")
    func lookbackForWetRoads() async {
        let harness = StoreHarness()
        defer { harness.tearDown() }
        _ = await harness.store().snapshot(center: TestTime.newYork, radius: 0, purpose: .foreground)
        let previousNoon = TestTime.calendar.date(from: DateComponents(year: 2026, month: 6, day: 7, hour: 12))!
        #expect(harness.provider.requestedHours.map(\.start) == [previousNoon])
        #expect(
            harness.provider.requestedHours.map(\.end) == [
                TestTime.calendar.date(from: DateComponents(year: 2026, month: 6, day: 15))!
            ])
    }

    // Scenario: weather-data: Alerts unsupported in the region
    @Test("Alerts unsupported in the region")
    func alertsUnsupportedInTheRegion() async {
        let harness = StoreHarness()
        defer { harness.tearDown() }
        harness.provider.withoutAlerts = [harness.points()[0].coordinate]
        let snapshot = await harness.store().snapshot(center: TestTime.newYork, radius: 0, purpose: .foreground)
        #expect(snapshot.alertsUnavailable == [.center])
        let input = snapshot.evaluationInput(
            profile: ProfileSnapshot(limits: Limits(), windows: []), now: harness.clock.now, calendar: TestTime.calendar
        )
        #expect(input?.alertsAvailable == false)
    }

    @Test func alertsAreMergedAcrossPoints() async {
        let store = ForecastStore(
            provider: AlertingProvider(),
            cache: ForecastCache(directory: FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)),
            budget: nil, calendar: TestTime.calendar, clock: { TestTime.morning })
        let snapshot = await store.snapshot(center: TestTime.newYork, radius: 40_000, purpose: .foreground)
        #expect(snapshot.alerts.count == 1)
        #expect(snapshot.alerts.first?.positions.count == 9)
        #expect(snapshot.alerts.first?.severity == .severe)
    }
}

struct AlertingProvider: WeatherProviding {
    let makesNetworkRequests = false
    func forecast(at coordinate: RoundedCoordinate, hours: DateInterval, days: DateInterval)
        async throws(WeatherSourceError) -> PointForecast
    {
        PointForecast(
            hours: [RecordingProvider.hour(hours.start)], days: [],
            alerts: [PointAlert(name: "Severe Thunderstorm Warning", severity: .severe)])
    }
}
