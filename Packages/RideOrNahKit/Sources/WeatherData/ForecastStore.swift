import Foundation
import VerdictEngine

/// Why a forecast is wanted. Each purpose reuses cached data for a different length of time.
public enum RefreshPurpose: String, Sendable, CaseIterable {
    /// The app opening or coming to the foreground.
    case foreground
    /// A background refresh, such as before the morning notification.
    case background
    /// A widget building its timeline.
    case widget
    /// The rider asked, for example by pulling to refresh.
    case manual

    /// Cached forecasts younger than this are used instead of fetching.
    public var reuseInterval: TimeInterval {
        switch self {
        case .foreground: 60 * 60
        case .background, .widget: 2 * 60 * 60
        case .manual: 15 * 60
        }
    }
}

public enum ForecastOutcome: Sendable, Equatable {
    case complete
    /// A manual refresh found nothing old enough to refetch.
    case alreadyCurrent
    /// Some points failed; their cached data, if any, is used.
    case partial(failed: [SamplePosition])
    case offline
    case serviceUnavailable
    case notAuthorized
    /// The daily request budget ran out; cached data is used until tomorrow.
    case budgetLimited
}

/// The forecasts for one evaluation location and radius, ready for the verdict engine.
public struct ForecastSnapshot: Sendable, Equatable {
    /// One per sample point; a point with no data at all has no hours.
    public var samples: [SampleForecast]
    public var sun: [DaySun]
    public var alerts: [AlertInfo]
    /// Points with data whose source offers no alerts.
    public var alertsUnavailable: [SamplePosition]
    /// The oldest fetch time among the samples used; nil when there's no data.
    public var fetchedAt: Date?
    public var outcome: ForecastOutcome
    /// Network requests made for this snapshot.
    public var networkRequests: Int

    /// Engine input for this snapshot, or nil when there's no forecast at all.
    public func evaluationInput(profile: ProfileSnapshot, now: Date, calendar: Calendar) -> EvaluationInput? {
        guard let fetchedAt else { return nil }
        return EvaluationInput(
            now: now, calendar: calendar, profile: profile, samples: samples, alerts: alerts,
            alertsAvailable: alertsUnavailable.isEmpty, sun: sun, fetchedAt: fetchedAt)
    }
}

/// Decides between cache and network for every sample point, keeps to the daily budget, and
/// fetches what's needed with a few requests in flight at once.
public actor ForecastStore {
    let provider: any WeatherProviding
    let cache: ForecastCache
    let budget: RequestBudget?
    let calendar: Calendar
    let clock: @Sendable () -> Date
    let maxConcurrentRequests: Int

    public init(
        provider: any WeatherProviding, cache: ForecastCache, budget: RequestBudget?, calendar: Calendar,
        maxConcurrentRequests: Int = 4, clock: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.provider = provider
        self.cache = cache
        self.budget = budget
        self.calendar = calendar
        self.maxConcurrentRequests = maxConcurrentRequests
        self.clock = clock
    }

    /// Hourly data from 12 hours before today through the end of the sixth day after today, so
    /// rain before the first ride window is known.
    public func requestRange(now: Date) -> (hours: DateInterval, days: DateInterval) {
        let today = calendar.startOfDay(for: now)
        let end = calendar.date(byAdding: .day, value: 7, to: today)!
        return (
            DateInterval(start: today.addingTimeInterval(-12 * 3600), end: end), DateInterval(start: today, end: end)
        )
    }

    public func snapshot(center: GeoCoordinate, radius: Double, purpose: RefreshPurpose) async -> ForecastSnapshot {
        let now = clock()
        await cache.purge(now: now)
        let points = SampleLayout.points(center: center, radius: radius)

        var entries: [SamplePosition: CachedForecast] = [:]
        var stale: [SamplePoint] = []
        for point in points {
            let cached = await cache.read(point.coordinate)
            if let cached { entries[point.position] = cached }
            if cached.map({ now.timeIntervalSince($0.fetchedAt) >= purpose.reuseInterval }) ?? true {
                stale.append(point)
            }
        }

        var outcome = ForecastOutcome.complete
        if stale.isEmpty && purpose == .manual { outcome = .alreadyCurrent }

        // Points are already ordered center first, so the budget favours the evaluation location.
        var toFetch = stale
        if provider.makesNetworkRequests, let budget {
            let granted = budget.reserve(stale.count, now: now, calendar: calendar)
            if granted < stale.count {
                toFetch = Array(stale.prefix(granted))
                outcome = .budgetLimited
            }
        }

        let range = requestRange(now: now)
        let results = await fetch(toFetch, range: range)
        var failures: [SamplePosition: WeatherSourceError] = [:]
        for (point, result) in results {
            switch result {
            case .success(let forecast):
                let entry = CachedForecast(fetchedAt: now, forecast: forecast)
                entries[point.position] = entry
                await cache.write(entry, for: point.coordinate)
            case .failure(let error):
                failures[point.position] = error
            }
        }

        if !failures.isEmpty, outcome != .budgetLimited {
            if failures.count == toFetch.count {
                let errors = Set(failures.values)
                outcome =
                    errors.contains(.notAuthorized)
                    ? .notAuthorized : errors.contains(.serviceUnavailable) ? .serviceUnavailable : .offline
            } else {
                outcome = .partial(failed: failures.keys.sorted())
            }
        }

        return snapshot(
            points: points, entries: entries, outcome: outcome,
            requests: provider.makesNetworkRequests ? toFetch.count : 0)
    }

    func fetch(_ points: [SamplePoint], range: (hours: DateInterval, days: DateInterval)) async
        -> [(SamplePoint, Result<PointForecast, WeatherSourceError>)]
    {
        let provider = self.provider
        return await withTaskGroup(of: (SamplePoint, Result<PointForecast, WeatherSourceError>).self) { group in
            var pending = points[...]
            var results: [(SamplePoint, Result<PointForecast, WeatherSourceError>)] = []
            func startNext() {
                guard let point = pending.popFirst() else { return }
                group.addTask {
                    do throws(WeatherSourceError) {
                        return (
                            point,
                            .success(
                                try await provider.forecast(at: point.coordinate, hours: range.hours, days: range.days))
                        )
                    } catch {
                        return (point, .failure(error))
                    }
                }
            }
            for _ in 0..<maxConcurrentRequests { startNext() }
            for await result in group {
                results.append(result)
                startNext()
            }
            return results.sorted { $0.0.position < $1.0.position }
        }
    }

    func snapshot(
        points: [SamplePoint], entries: [SamplePosition: CachedForecast], outcome: ForecastOutcome, requests: Int
    )
        -> ForecastSnapshot
    {
        let samples = points.map {
            SampleForecast(position: $0.position, hours: entries[$0.position]?.forecast.hours ?? [])
        }

        var alertPositions: [PointAlert: Set<SamplePosition>] = [:]
        var alertOrder: [PointAlert] = []
        var unavailable: [SamplePosition] = []
        for point in points {
            guard let entry = entries[point.position] else { continue }
            guard let alerts = entry.forecast.alerts else {
                unavailable.append(point.position)
                continue
            }
            for alert in alerts {
                if alertPositions[alert] == nil { alertOrder.append(alert) }
                alertPositions[alert, default: []].insert(point.position)
            }
        }
        let alerts = alertOrder.map { alert in
            AlertInfo(
                name: alert.name, severity: alert.severity, positions: alertPositions[alert] ?? [], active: alert.active
            )
        }

        return ForecastSnapshot(
            samples: samples,
            sun: entries[.center]?.forecast.days ?? entries.values.first?.forecast.days ?? [],
            alerts: alerts, alertsUnavailable: unavailable,
            fetchedAt: entries.values.filter { !$0.forecast.hours.isEmpty }.map(\.fetchedAt).min(),
            outcome: outcome, networkRequests: requests)
    }
}
