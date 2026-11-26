import Foundation
import Testing

@testable import VerdictEngine

/// Worst case across the radius, directions, explanations, stale data and the outlook.
struct RadiusAndFreshnessTests {
    static func rainAt8(on positions: Set<SamplePosition>) -> Fixture {
        var fixture = Fixture(positions: Fixture.radius)
        fixture.weather = { hour, position in
            if positions.contains(position) && Fixture.isHour(hour.start, 8) { hour.precipitationChance = 0.9 }
        }
        return fixture
    }

    // Scenario: ride-verdict: Storm at the edge of the radius
    @Test("Storm at the edge of the radius")
    func stormAtTheEdgeOfTheRadius() {
        let today = Self.rainAt8(on: [.ring(.w, .outer)]).today
        #expect(today.verdict == .nah)
        #expect(today.breaches(.precipitationChance).map(\.positions) == [[.ring(.w, .outer)]])
    }

    // Scenario: ride-verdict: Rain to the north only
    @Test("Rain to the north only")
    func rainToTheNorthOnly() {
        let today = Self.rainAt8(on: [.ring(.n, .outer), .ring(.ne, .outer)]).today
        let directions = Dictionary(uniqueKeysWithValues: (today.directions ?? []).map { ($0.direction, $0.verdict) })
        #expect(directions[.n] == .nah)
        #expect(directions[.ne] == .nah)
        #expect(today.clearDirections == [.e, .se, .s, .sw, .w, .nw])
    }

    // Scenario: ride-verdict: Missing direction
    @Test("Missing direction")
    func missingDirection() {
        var fixture = Fixture(positions: Fixture.radius)
        fixture.failed = [.ring(.sw, .outer)]
        let today = fixture.today
        #expect(today.directions?.first { $0.direction == .sw }?.verdict == .unknown)
        #expect(today.clearDirections == [.n, .ne, .e, .se, .s, .w, .nw])
    }

    // Scenario: ride-verdict: Local radius
    @Test("Local radius")
    func localRadius() {
        #expect(Fixture(positions: [.center]).today.directions == nil)
    }

    // Scenario: ride-verdict: Merged time range
    @Test("Merged time range")
    func mergedTimeRange() {
        var fixture = Fixture(positions: Fixture.radius)
        fixture.windows = [RideWindow(weekdays: [2], from: (16, 0), to: (19, 0))]
        let gusts: [Int: Double] = [16: 32, 17: 34, 18: 33]
        fixture.weather = { hour, position in
            if position == .ring(.w, .outer), let mph = gusts[Fixture.hour(hour.start)],
                Fixture.calendar.isDate(hour.start, inSameDayAs: Fixture.monday)
            {
                hour.windGust = Units.mph(mph)
            }
        }
        let breaches = fixture.today.breaches(.gusts)
        #expect(breaches.count == 1)
        #expect(breaches.first?.range == DateInterval(start: Fixture.at(16), end: Fixture.at(19)))
        #expect(breaches.first?.directions == [.w])
        #expect(breaches.first?.worstValue == Units.mph(34))
        #expect(breaches.first?.limit == Units.mph(30))
    }

    @Test func breachesSortBySeverityThenStart() {
        var fixture = Fixture()
        fixture.weather = { hour, _ in
            if Fixture.isHour(hour.start, 7) { hour.uvIndex = 9 }
            if Fixture.isHour(hour.start, 17) { hour.precipitationChance = 0.9 }
        }
        let breaches = fixture.today.breaches
        #expect(breaches.map(\.severity) == [.hard, .soft])
        #expect(breaches.map(\.factor) == [.precipitationChance, .uv])
    }

    // Scenario: ride-verdict: Outdated forecast
    @Test("Outdated forecast")
    func outdatedForecast() {
        var fixture = Fixture()
        fixture.fetchedAt = fixture.now.addingTimeInterval(-13 * 3600)
        #expect(fixture.today.verdict == .unknown)
        #expect(fixture.today.unknownReason == .forecastTooOld)
    }

    // Scenario: ride-verdict: Stale but usable
    @Test("Stale but usable")
    func staleButUsable() {
        var fixture = Fixture()
        fixture.fetchedAt = fixture.now.addingTimeInterval(-5 * 3600)
        #expect(fixture.today.verdict == .ride)
        #expect(fixture.today.freshness == .stale(age: 5 * 3600))
    }

    // Scenario: ride-verdict: Later days expire
    @Test("Later days expire")
    func laterDaysExpire() {
        var fixture = Fixture()
        fixture.fetchedAt = fixture.now.addingTimeInterval(-25 * 3600)
        #expect(fixture.outlook.map(\.verdict) == Array(repeating: .unknown, count: 7))
    }

    @Test func laterDaysStayUsableUntil24Hours() {
        var fixture = Fixture()
        fixture.fetchedAt = fixture.now.addingTimeInterval(-13 * 3600)
        let outlook = fixture.outlook
        #expect(outlook[0].verdict == .unknown)
        #expect(outlook[1].verdict == .ride)
    }

    // Scenario: ride-verdict: Missing ring point
    @Test("Missing ring point")
    func missingRingPoint() {
        var fixture = Fixture(positions: Fixture.radius)
        fixture.failed = [.ring(.sw, .outer)]
        #expect(fixture.today.verdict == .ride)
        #expect(fixture.today.coverage == .partial(missing: [.sw]))
    }

    // Scenario: ride-verdict: A known Nah outranks Unknown
    @Test("A known Nah outranks Unknown")
    func knownNahOutranksUnknown() {
        var fixture = Fixture()
        fixture.weather = { hour, _ in
            if Fixture.isHour(hour.start, 8) { hour.temperature = nil }
            if Fixture.isHour(hour.start, 16) { hour.precipitationChance = 0.9 }
        }
        #expect(fixture.today.windows.map(\.verdict) == [.unknown, .nah])
        #expect(fixture.today.verdict == .nah)
    }

    // Scenario: ride-verdict: Outlook confidence
    @Test("Outlook confidence")
    func outlookConfidence() {
        let outlook = Fixture().outlook
        #expect(outlook.count == 7)
        #expect(outlook.map(\.confidence) == [.normal, .normal, .normal, .lower, .lower, .lower, .lower])
    }
}
