import Foundation
import Testing

@testable import VerdictEngine

/// Ride opportunities and time-range evaluation. Saturday is day 5.
struct OpportunityTests {
    static let saturday = 5

    /// Saturday rains in every hour `isRainy` returns true for.
    static func saturday(rainy isRainy: @escaping (Int) -> Bool) -> Fixture {
        var fixture = Fixture()
        fixture.weather = { hour, _ in
            let onSaturday = Fixture.calendar.isDate(hour.start, inSameDayAs: Fixture.at(day: saturday, 12))
            if onSaturday && isRainy(Fixture.hour(hour.start)) { hour.precipitationChance = 0.9 }
        }
        return fixture
    }

    // Scenario: ride-verdict: Saturday afternoon gap
    @Test("Saturday afternoon gap")
    func saturdayAfternoonGap() {
        var fixture = Self.saturday { $0 < 11 }
        fixture.sun = { day in (Fixture.at(day: day, 6), Fixture.at(day: day, 17, 30)) }
        #expect(
            fixture.outlook[Self.saturday].opportunities == [
                DateInterval(start: Fixture.at(day: Self.saturday, 11), end: Fixture.at(day: Self.saturday, 17, 30))
            ])
    }

    // Scenario: ride-verdict: Too short
    @Test("Too short")
    func tooShort() {
        let fixture = Self.saturday { $0 != 12 }
        #expect(fixture.outlook[Self.saturday].opportunities.isEmpty)
    }

    // Scenario: ride-verdict: Busy good day
    @Test("Busy good day")
    func busyGoodDay() {
        // Daylight 04:00–22:00: clear 04–06, 07–10, 11–15 and 16–21, rain in between.
        var fixture = Self.saturday { [6, 10, 15, 21].contains($0) }
        fixture.sun = { day in (Fixture.at(day: day, 4), Fixture.at(day: day, 22)) }
        let at = { Fixture.at(day: Self.saturday, $0) }
        #expect(
            fixture.outlook[Self.saturday].opportunities == [
                DateInterval(start: at(16), end: at(21)),
                DateInterval(start: at(11), end: at(15)),
                DateInterval(start: at(7), end: at(10)),
            ])
    }

    // Scenario: ride-verdict: Ended hours
    @Test("Ended hours")
    func endedHours() {
        var fixture = Fixture()
        fixture.now = Fixture.at(13)
        fixture.weather = { hour, _ in
            let onMonday = Fixture.calendar.isDate(hour.start, inSameDayAs: Fixture.monday)
            if onMonday && !(9..<17).contains(Fixture.hour(hour.start)) { hour.precipitationChance = 0.9 }
        }
        #expect(fixture.today.opportunities == [DateInterval(start: Fixture.at(13), end: Fixture.at(17))])
    }

    // Scenario: ride-verdict: No opportunities without data
    @Test("No opportunities without data")
    func noOpportunitiesWithoutData() {
        var partial = Fixture(positions: Fixture.radius)
        partial.failed = [.ring(.sw, .outer)]
        #expect(partial.outlook.allSatisfy { $0.opportunities.isEmpty })

        var expired = Fixture()
        expired.fetchedAt = expired.now.addingTimeInterval(-25 * 3600)
        #expect(expired.outlook.allSatisfy { $0.opportunities.isEmpty })

        #expect(!Fixture().outlook[Self.saturday].opportunities.isEmpty)
    }

    // Scenario: ride-verdict: Added ride turns rainy
    @Test("Added ride turns rainy")
    func addedRideTurnsRainy() {
        let fixture = Self.saturday { $0 == 15 }
        let range = DateInterval(start: Fixture.at(day: Self.saturday, 11), end: Fixture.at(day: Self.saturday, 17, 30))
        let evaluation = VerdictEngine.evaluate(range: range, in: fixture.input)
        #expect(evaluation.verdict == .nah)
        #expect(
            evaluation.breaches.filter { $0.factor.group == .precipitation }.map(\.range.start) == [
                Fixture.at(day: Self.saturday, 15)
            ])
    }

    @Test func rangeOnStaleDataIsUnknown() {
        var fixture = Fixture()
        fixture.fetchedAt = fixture.now.addingTimeInterval(-25 * 3600)
        let range = DateInterval(start: Fixture.at(day: Self.saturday, 11), end: Fixture.at(day: Self.saturday, 14))
        let evaluation = VerdictEngine.evaluate(range: range, in: fixture.input)
        #expect(evaluation.verdict == .unknown)
        #expect(evaluation.unknownReason == .forecastTooOld)
    }
}
