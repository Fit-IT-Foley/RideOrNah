import Foundation
import Testing

@testable import VerdictEngine

/// One rule per factor, plus limits and missing values. Breaches are put in the 08:00 hour of
/// Monday's 07:00–09:00 window unless a test says otherwise.
struct FactorTests {
    /// A fixture whose 07:00–09:00 window hours get `change`.
    static func morning(_ change: @escaping (inout HourConditions) -> Void) -> Fixture {
        var fixture = Fixture()
        fixture.weather = { hour, _ in
            if [7, 8].contains(Fixture.hour(hour.start))
                && Fixture.calendar.isDate(hour.start, inSameDayAs: Fixture.monday)
            {
                change(&hour)
            }
        }
        return fixture
    }

    // MARK: Limits

    // Scenario: ride-verdict: Value exactly at the limit
    @Test("Value exactly at the limit")
    func valueExactlyAtTheLimit() {
        let limit = Fixture.standardLimits.gusts.soft!
        let breaches = Self.morning { $0.windGust = limit }.today.breaches(.gusts)
        #expect(breaches.map(\.severity) == [.soft])
    }

    // Scenario: ride-verdict: Disabled factor
    @Test("Disabled factor")
    func disabledFactor() {
        var fixture = Self.morning { $0.uvIndex = 11 }
        fixture.limits.uv = .off
        #expect(fixture.today.breaches(.uv).isEmpty)
        #expect(fixture.today.verdict == .ride)
    }

    // Scenario: ride-verdict: Soft-only factor
    @Test("Soft-only factor")
    func softOnlyFactor() {
        var fixture = Self.morning { $0.uvIndex = 11 }
        fixture.limits.uv = ThresholdLimit(soft: 8, hard: nil)
        #expect(fixture.today.breaches(.uv).map(\.severity) == [.soft])
    }

    // MARK: Missing values

    // Scenario: ride-verdict: UV missing
    @Test("UV missing")
    func uvMissing() {
        var fixture = Fixture()
        fixture.weather = { hour, _ in hour.uvIndex = nil }
        #expect(fixture.today.verdict == .ride)
        #expect(fixture.today.notChecked.contains(.uv))
    }

    // Scenario: ride-verdict: Temperature missing here
    @Test("Temperature missing here")
    func temperatureMissingHere() {
        var fixture = Fixture()
        fixture.weather = { hour, position in
            if position == .center && Fixture.isHour(hour.start, 8) { hour.temperature = nil }
        }
        #expect(fixture.today.windows[0].verdict == .unknown)
        #expect(fixture.today.windows[0].unknownReason == .missingData)
    }

    // MARK: Precipitation

    // Scenario: ride-verdict: Chance exceeds the hard limit
    @Test("Chance exceeds the hard limit")
    func chanceExceedsTheHardLimit() {
        let today = Self.morning { $0.precipitationChance = 0.7 }.today
        #expect(today.breaches(.precipitationChance).map(\.severity) == [.hard])
        #expect(today.verdict == .nah)
    }

    // Scenario: ride-verdict: Low chance but heavy intensity
    @Test("Low chance but heavy intensity")
    func lowChanceButHeavyIntensity() {
        let today = Self.morning {
            $0.precipitationChance = 0.4
            $0.precipitationIntensity = 2
        }.today
        #expect(today.breaches(.precipitationIntensity).map(\.severity) == [.hard])
        #expect(today.verdict == .nah)
    }

    // Scenario: ride-verdict: Thunderstorm
    @Test("Thunderstorm")
    func thunderstorm() {
        let today = Self.morning {
            $0.precipitationChance = 0.1
            $0.hazards = .thunderstorm
        }.today
        #expect(today.breaches(.storm).map(\.severity) == [.hard])
        #expect(today.breaches(.precipitationChance).isEmpty)
        #expect(today.verdict == .nah)
    }

    // MARK: Temperature and humidity

    // Scenario: ride-verdict: Cold morning
    @Test("Cold morning")
    func coldMorning() {
        let today = Self.morning {
            $0.temperature = Units.fahrenheit(45)
            $0.feelsLike = Units.fahrenheit(45)
        }.today
        #expect(today.breaches(.cold).map(\.severity) == [.soft])
    }

    // Scenario: ride-verdict: Muggy afternoon
    @Test("Muggy afternoon")
    func muggyAfternoon() {
        let today = Self.morning {
            $0.temperature = 31
            $0.feelsLike = 38.3
        }.today
        #expect(today.breaches(.heat).map(\.severity) == [.hard])
    }

    @Test(arguments: [
        (cold: 10.0, expected: [Severity.soft]), (cold: 10.01, expected: []), (cold: 4.4, expected: [.hard]),
    ])
    func coldBoundariesCountAtTheLimit(cold: Double, expected: [Severity]) {
        let today = Self.morning {
            $0.temperature = cold
            $0.feelsLike = 20
        }.today
        #expect(today.breaches(.cold).map(\.severity) == expected)
    }

    @Test(arguments: [
        (feelsLike: 32.0, expected: [Severity.soft]), (feelsLike: 31.99, expected: []),
        (feelsLike: 37.8, expected: [.hard]),
    ])
    func heatBoundariesCountAtTheLimit(feelsLike: Double, expected: [Severity]) {
        #expect(Self.morning { $0.feelsLike = feelsLike }.today.breaches(.heat).map(\.severity) == expected)
    }

    // MARK: Wind

    // Scenario: ride-verdict: Calm average, strong gusts
    @Test("Calm average, strong gusts")
    func calmAverageStrongGusts() {
        let today = Self.morning {
            $0.windSpeed = Units.kmh(19)
            $0.windGust = Units.mph(42)
        }.today
        #expect(today.breaches(.wind).isEmpty)
        #expect(today.breaches(.gusts).map(\.severity) == [.hard])
    }

    // Scenario: ride-verdict: Gust data missing
    @Test("Gust data missing")
    func gustDataMissing() {
        let today = Self.morning { $0.windGust = nil }.today
        #expect(today.breaches(in: .wind).isEmpty)
        #expect(today.breaches(in: .gusts).isEmpty)
        #expect(today.notChecked.contains(.gusts))
    }

    // MARK: UV

    // Scenario: ride-verdict: High UV
    @Test("High UV")
    func highUV() {
        #expect(Self.morning { $0.uvIndex = 9 }.today.breaches(.uv).map(\.severity) == [.soft])
    }

    // MARK: Wet roads

    // Scenario: ride-verdict: Rain ended before the commute
    @Test("Rain ended before the commute")
    func rainEndedBeforeTheCommute() {
        var fixture = Fixture()
        fixture.weather = { hour, _ in
            if Fixture.isHour(hour.start, 5) { hour.precipitationIntensity = 1 }
        }
        let wet = fixture.today.breaches(.wetRoads)
        #expect(wet.map(\.severity) == [.soft])
        #expect(wet.map(\.range) == [DateInterval(start: Fixture.at(7), end: Fixture.at(8))])
    }

    // Scenario: ride-verdict: No lookback data
    @Test("No lookback data")
    func noLookbackData() {
        var fixture = Fixture()
        fixture.hoursStart = Fixture.at(7)
        #expect(fixture.today.partiallyChecked.contains(.wetRoads))
    }

    // MARK: Ice

    // Scenario: ride-verdict: Cold and damp
    @Test("Cold and damp")
    func coldAndDamp() {
        var fixture = Fixture()
        fixture.weather = { hour, _ in
            if Fixture.isHour(hour.start, 5) { hour.precipitationIntensity = 1 }
            if Fixture.isHour(hour.start, 7) { hour.temperature = 1 }
        }
        #expect(fixture.today.breaches(.ice).map(\.severity) == [.hard])
    }

    // Scenario: ride-verdict: Cold but dry
    @Test("Cold but dry")
    func coldButDry() {
        let today = Self.morning {
            $0.temperature = 1
            $0.feelsLike = 1
            $0.humidity = 0.6
        }.today
        #expect(today.breaches(.ice).isEmpty)
        #expect(!today.breaches(.cold).isEmpty)
    }

    // MARK: Visibility

    // Scenario: ride-verdict: Dense fog
    @Test("Dense fog")
    func denseFog() {
        let today = Self.morning { $0.visibility = 160 }.today
        #expect(today.breaches(.visibility).map(\.severity) == [.hard])
    }

    // Scenario: ride-verdict: Fog without visibility data
    @Test("Fog without visibility data")
    func fogWithoutVisibilityData() {
        let today = Self.morning {
            $0.visibility = nil
            $0.hazards = .fog
        }.today
        #expect(today.breaches(in: .visibility).map(\.severity) == [.soft])
    }

    // MARK: Alerts

    static func alert(_ severity: AlertSeverity, at position: SamplePosition = .center, active: DateInterval?)
        -> Fixture
    {
        var fixture = Fixture(positions: Fixture.radius)
        fixture.alerts = [AlertInfo(name: "Test Warning", severity: severity, positions: [position], active: active)]
        return fixture
    }

    static let morningAlert = DateInterval(start: Fixture.at(7, 30), end: Fixture.at(8, 30))

    // Scenario: ride-verdict: Severe thunderstorm warning
    @Test("Severe thunderstorm warning")
    func severeThunderstormWarning() {
        var fixture = Self.alert(.severe, at: .ring(.ne, .outer), active: Self.morningAlert)
        fixture.alerts[0].name = "Severe Thunderstorm Warning"
        let today = fixture.today
        #expect(today.verdict == .nah)
        let alert = today.breaches(.alert)
        #expect(alert.map(\.alertName) == ["Severe Thunderstorm Warning"])
        #expect(alert.first?.directions == [.ne])
    }

    // Scenario: ride-verdict: Moderate alert
    @Test("Moderate alert")
    func moderateAlert() {
        #expect(Self.alert(.moderate, active: Self.morningAlert).today.verdict == .maybe)
    }

    // Scenario: ride-verdict: Minor alert
    @Test("Minor alert")
    func minorAlert() {
        #expect(Self.alert(.minor, active: Self.morningAlert).today.verdict == .ride)
    }

    // Scenario: ride-verdict: Alert ends before the window
    @Test("Alert ends before the window")
    func alertEndsBeforeTheWindow() {
        let fixture = Self.alert(.severe, active: DateInterval(start: Fixture.at(3), end: Fixture.at(6)))
        #expect(fixture.today.windows[0].breaches.isEmpty)
        #expect(fixture.today.verdict == .ride)
    }

    // Scenario: ride-verdict: Alert without an active period
    @Test("Alert without an active period")
    func alertWithoutAnActivePeriod() {
        let outlook = Self.alert(.severe, active: nil).outlook
        #expect(outlook[0].verdict == .nah)
        #expect(outlook[1].verdict == .ride)
    }

    // Scenario: ride-verdict: Alerts unsupported in the region
    @Test("Alerts unsupported in the region")
    func alertsUnsupportedInTheRegion() {
        var fixture = Fixture()
        fixture.alertsAvailable = false
        #expect(fixture.today.breaches(.alert).isEmpty)
        #expect(fixture.today.notChecked.contains(.alert))
    }
}
