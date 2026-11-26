import Foundation

@testable import VerdictEngine

enum Units {
    static func mph(_ value: Double) -> Double { value * 0.44704 }
    static func kmh(_ value: Double) -> Double { value / 3.6 }
    static func fahrenheit(_ value: Double) -> Double { (value - 32) * 5 / 9 }
}

/// Builds evaluation inputs for tests. Day 0 is Monday 8 June 2026 in New York; every hour
/// starts clean, and `weather` changes the hours a test cares about.
struct Fixture {
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        return calendar
    }()
    static let monday = calendar.date(from: DateComponents(year: 2026, month: 6, day: 8))!

    /// Local time on `day` (0 is Monday, 5 is Saturday).
    static func at(day: Int = 0, _ hour: Int, _ minute: Int = 0) -> Date {
        let date = calendar.date(byAdding: .day, value: day, to: monday)!
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: date)!
    }

    static let weekdays: Set<Int> = [2, 3, 4, 5, 6]
    static let weekend: Set<Int> = [1, 7]
    /// Monday to Friday, 07:00–09:00 and 16:00–18:00.
    static let commute = [
        RideWindow(weekdays: weekdays, from: (7, 0), to: (9, 0)),
        RideWindow(weekdays: weekdays, from: (16, 0), to: (18, 0)),
    ]
    static let weekendDays = [RideWindow(weekdays: weekend, from: (9, 0), to: (17, 0))]
    static let ring: [SamplePosition] = CompassDirection.allCases.map { .ring($0, .outer) }
    static let radius: [SamplePosition] = [.center] + ring

    /// Close to the defaults new profiles get.
    static let standardLimits = Limits(
        precipitation: PrecipitationLimit(
            chance: ThresholdLimit(soft: 0.3, hard: 0.6), intensity: ThresholdLimit(soft: 0.1, hard: 1)),
        cold: ThresholdLimit(soft: 10, hard: 4.4),
        heat: ThresholdLimit(soft: 32, hard: 37.8),
        humidity: .off,
        wind: ThresholdLimit(soft: Units.mph(20), hard: Units.mph(30)),
        gusts: ThresholdLimit(soft: Units.mph(30), hard: Units.mph(40)),
        uv: ThresholdLimit(soft: 8),
        visibility: ThresholdLimit(soft: 1609, hard: 400),
        wetRoads: WetRoadsLimit(duration: 2 * 3600, severity: .soft),
        ice: IceLimit(threshold: 3),
        alertsEnabled: true)

    var now = Fixture.at(6)
    var fetchedAt: Date?
    var limits = Fixture.standardLimits
    var windows = Fixture.commute
    var minimumRideDuration: TimeInterval = 2 * 3600
    var positions: [SamplePosition] = [.center]
    /// Points whose request failed: passed with no hours.
    var failed: Set<SamplePosition> = []
    var alerts: [AlertInfo] = []
    var alertsAvailable = true
    var hoursStart = Fixture.at(day: -1, 0)
    var hoursEnd = Fixture.at(day: 8, 0)
    /// Sunrise and sunset for a day offset; nil values mean missing.
    var sun: (Int) -> (sunrise: Date?, sunset: Date?) = { day in (Fixture.at(day: day, 6), Fixture.at(day: day, 20)) }
    /// Changes an hour at a sample point. Starts from clean, mild conditions.
    var weather: (inout HourConditions, SamplePosition) -> Void = { _, _ in }

    static func clean(_ start: Date) -> HourConditions {
        HourConditions(
            start: start, temperature: 20, feelsLike: 20, humidity: 0.5, windSpeed: 3, windGust: 5, uvIndex: 3,
            visibility: 10_000, precipitationChance: 0, precipitationIntensity: 0)
    }

    var input: EvaluationInput {
        var hourStarts: [Date] = []
        var hour = hoursStart
        while hour < hoursEnd {
            hourStarts.append(hour)
            hour = hour.addingTimeInterval(3600)
        }
        let samples = positions.map { position in
            SampleForecast(
                position: position,
                hours: failed.contains(position)
                    ? []
                    : hourStarts.map { start in
                        var conditions = Fixture.clean(start)
                        weather(&conditions, position)
                        return conditions
                    })
        }
        let days = (-1...8).map { day in
            let times = sun(day)
            return DaySun(day: Fixture.at(day: day, 12), sunrise: times.sunrise, sunset: times.sunset)
        }
        return EvaluationInput(
            now: now, calendar: Fixture.calendar,
            profile: ProfileSnapshot(limits: limits, windows: windows, minimumRideDuration: minimumRideDuration),
            samples: samples, alerts: alerts, alertsAvailable: alertsAvailable, sun: days, fetchedAt: fetchedAt ?? now)
    }

    var outlook: [DayEvaluation] { VerdictEngine.outlook(for: input) }
    var today: DayEvaluation { outlook[0] }

    /// True when `date` falls in the hour starting at `hour` on `day`.
    static func isHour(_ date: Date, day: Int = 0, _ hour: Int) -> Bool { date == at(day: day, hour) }

    static func hour(_ date: Date) -> Int { calendar.component(.hour, from: date) }
}

extension DayEvaluation {
    func breaches(_ factor: Factor) -> [Breach] { breaches.filter { $0.factor == factor } }
    func breaches(in group: Factor.Group) -> [Breach] { breaches.filter { $0.factor.group == group } }
}
