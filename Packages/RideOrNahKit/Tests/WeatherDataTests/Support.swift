import Foundation
import VerdictEngine

@testable import WeatherData

enum TestTime {
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        return calendar
    }()
    /// Monday 8 June 2026, 06:00 New York.
    static let morning = calendar.date(from: DateComponents(year: 2026, month: 6, day: 8, hour: 6))!
    static let newYork = GeoCoordinate(latitude: 40.712776, longitude: -74.005974)
}

/// A clock tests can move.
final class TestClock: @unchecked Sendable {
    private let lock = NSLock()
    private var current: Date
    init(_ date: Date = TestTime.morning) { current = date }
    var now: Date { lock.withLock { current } }
    func advance(_ seconds: TimeInterval) { lock.withLock { current = current.addingTimeInterval(seconds) } }
    var function: @Sendable () -> Date { { self.now } }
}

/// Records every request, can fail chosen points, and tracks how many run at once.
final class RecordingProvider: WeatherProviding, @unchecked Sendable {
    private let lock = NSLock()
    private var calls: [(RoundedCoordinate, DateInterval)] = []
    private var inFlight = 0
    private var peak = 0
    var failing: [RoundedCoordinate: WeatherSourceError] = [:]
    var failEverything: WeatherSourceError?
    var withoutAlerts: Set<RoundedCoordinate> = []
    let makesNetworkRequests = true

    var requestCount: Int { lock.withLock { calls.count } }
    var requestedHours: [DateInterval] { lock.withLock { calls.map(\.1) } }
    var peakConcurrency: Int { lock.withLock { peak } }

    func forecast(at coordinate: RoundedCoordinate, hours: DateInterval, days: DateInterval)
        async throws(WeatherSourceError) -> PointForecast
    {
        lock.withLock {
            calls.append((coordinate, hours))
            inFlight += 1
            peak = max(peak, inFlight)
        }
        try? await Task.sleep(for: .milliseconds(5))
        lock.withLock { inFlight -= 1 }
        if let error = failEverything ?? lock.withLock({ failing[coordinate] }) { throw error }
        return PointForecast(
            hours: [Self.hour(hours.start)], days: [DaySun(day: days.start, sunrise: nil, sunset: nil)],
            alerts: withoutAlerts.contains(coordinate) ? nil : [])
    }

    static func hour(_ start: Date) -> HourConditions {
        HourConditions(
            start: start, temperature: 20, feelsLike: 20, humidity: 0.5, windSpeed: 3, windGust: 5, uvIndex: 3,
            visibility: 10_000, precipitationChance: 0, precipitationIntensity: 0)
    }
}

/// A fresh cache directory and budget suite for one test.
struct StoreHarness {
    let directory = FileManager.default.temporaryDirectory.appending(path: "ForecastCache-\(UUID().uuidString)")
    let suite = "rideornah-tests-\(UUID().uuidString)"
    let clock = TestClock()
    let provider = RecordingProvider()

    var cache: ForecastCache { ForecastCache(directory: directory) }
    var budget: RequestBudget { RequestBudget(suiteName: suite) }

    func store(provider: (any WeatherProviding)? = nil) -> ForecastStore {
        ForecastStore(
            provider: provider ?? self.provider, cache: cache, budget: budget, calendar: TestTime.calendar,
            clock: clock.function)
    }

    func points(radius: Double = 40_000) -> [SamplePoint] {
        SampleLayout.points(center: TestTime.newYork, radius: radius)
    }

    /// Caches every point as fetched `age` seconds before now.
    func seedCache(age: TimeInterval, radius: Double = 40_000) async {
        let fetchedAt = clock.now.addingTimeInterval(-age)
        for point in points(radius: radius) {
            await cache.write(
                CachedForecast(
                    fetchedAt: fetchedAt,
                    forecast: PointForecast(hours: [RecordingProvider.hour(fetchedAt)], days: [], alerts: [])),
                for: point.coordinate)
        }
    }

    func tearDown() {
        try? FileManager.default.removeItem(at: directory)
        UserDefaults.standard.removePersistentDomain(forName: suite)
    }
}
