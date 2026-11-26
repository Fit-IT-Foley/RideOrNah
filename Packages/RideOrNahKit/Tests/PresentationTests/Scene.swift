import Foundation
import RiderSettings
import VerdictEngine

@testable import Presentation
@testable import WeatherData

/// A forecast scene for presentation tests: Monday 8 June 2026 in New York, every hour mild and
/// clear unless `weather` changes it, evaluated by the real engine.
struct Scene {
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        return calendar
    }()
    static func at(day: Int = 0, _ hour: Int, _ minute: Int = 0) -> Date {
        let date = calendar.date(
            byAdding: .day, value: day, to: calendar.date(from: DateComponents(year: 2026, month: 6, day: 8))!)!
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: date)!
    }
    static func hour(_ date: Date) -> Int { calendar.component(.hour, from: date) }
    static let ring: [SamplePosition] = CompassDirection.allCases.map { .ring($0, .outer) }

    var now = Scene.at(6)
    var fetchedAt: Date?
    var profile = RiderProfile.defaults(named: "Commuter", style: .commute)
    var radius = RadiusPreset.km40
    var units = UnitSystem.imperial
    var positions: [SamplePosition] = [.center] + Scene.ring
    var failed: Set<SamplePosition> = []
    var outcome = ForecastOutcome.complete
    var sunrise = (6, 0)
    var sunset = (20, 0)
    var weather: (inout HourConditions, SamplePosition) -> Void = { _, _ in }

    var formatter: DisplayFormatter { DisplayFormatter(units: units, calendar: Scene.calendar) }

    var snapshot: ForecastSnapshot {
        var starts: [Date] = []
        var hour = Scene.at(day: -1, 12)
        while hour < Scene.at(day: 7, 0) {
            starts.append(hour)
            hour = hour.addingTimeInterval(3600)
        }
        let samples = positions.map { position in
            SampleForecast(
                position: position,
                hours: failed.contains(position)
                    ? []
                    : starts.map { start in
                        var conditions = HourConditions(
                            start: start, temperature: 20, feelsLike: 20, humidity: 0.5, windSpeed: 3, windGust: 5,
                            uvIndex: 3, visibility: 10_000, precipitationChance: 0, precipitationIntensity: 0)
                        weather(&conditions, position)
                        return conditions
                    })
        }
        let days = (0..<7).map { day in
            DaySun(
                day: Scene.at(day: day, 12), sunrise: Scene.at(day: day, sunrise.0, sunrise.1),
                sunset: Scene.at(day: day, sunset.0, sunset.1))
        }
        return ForecastSnapshot(
            samples: samples, sun: days, alerts: [], alertsUnavailable: [], fetchedAt: fetchedAt ?? now,
            outcome: outcome,
            networkRequests: 0)
    }

    var outlook: [DayEvaluation] {
        let input = snapshot.evaluationInput(profile: profile.snapshot, now: now, calendar: Scene.calendar)!
        return VerdictEngine.outlook(for: input)
    }

    var place: ResolvedLocation {
        ResolvedLocation(name: "Home", coordinate: GeoCoordinate(latitude: 40.71, longitude: -74.01))
    }

    var today: TodayContent {
        TodayPresenter(formatter: formatter).content(
            outlook: outlook, snapshot: snapshot, place: place, profile: profile, radius: radius, now: now)
    }
}
