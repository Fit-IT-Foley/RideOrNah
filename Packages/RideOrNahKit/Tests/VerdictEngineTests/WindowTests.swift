import Foundation
import Testing

@testable import VerdictEngine

/// Verdict states, which hours count, and days with no or ended windows.
struct WindowTests {
    // Scenario: ride-verdict: Clean forecast
    @Test("Clean forecast")
    func cleanForecast() {
        let today = Fixture(positions: Fixture.radius).today
        #expect(today.verdict == .ride)
        #expect(today.breaches.isEmpty)
    }

    // Scenario: ride-verdict: Only soft breaches
    @Test("Only soft breaches")
    func onlySoftBreaches() {
        var fixture = Fixture()
        fixture.weather = { hour, _ in hour.uvIndex = 9 }
        #expect(fixture.today.verdict == .maybe)
        #expect(!fixture.today.breaches.isEmpty)
        #expect(fixture.today.breaches.allSatisfy { $0.severity == .soft })
    }

    // Scenario: ride-verdict: Any hard breach
    @Test("Any hard breach")
    func anyHardBreach() {
        var fixture = Fixture(positions: Fixture.radius)
        fixture.weather = { hour, position in
            if Fixture.isHour(hour.start, 8) && position == .ring(.w, .outer) { hour.windGust = Units.mph(42) }
        }
        #expect(fixture.today.verdict == .nah)
    }

    // Scenario: ride-verdict: Window boundaries
    @Test("Window boundaries")
    func windowBoundaries() {
        var fixture = Fixture()
        fixture.windows = [RideWindow(weekdays: [2], from: (7, 30), to: (9, 0))]
        #expect(fixture.today.windows[0].evaluatedHours == [Fixture.at(7), Fixture.at(8)])
    }

    // Scenario: ride-verdict: Rain outside the windows
    @Test("Rain outside the windows")
    func rainOutsideTheWindows() {
        var fixture = Fixture()
        fixture.weather = { hour, _ in
            if [12, 13].contains(Fixture.hour(hour.start)) {
                hour.precipitationChance = 0.9
                hour.precipitationIntensity = 4
            }
        }
        #expect(fixture.today.verdict == .ride)
    }

    // Scenario: ride-verdict: One bad window
    @Test("One bad window")
    func oneBadWindow() {
        var fixture = Fixture()
        fixture.weather = { hour, _ in
            if Fixture.isHour(hour.start, 16) { hour.precipitationChance = 0.9 }
        }
        #expect(fixture.today.windows.map(\.verdict) == [.ride, .nah])
        #expect(fixture.today.verdict == .nah)
    }

    // Scenario: ride-verdict: Weekend-only rider on a Tuesday
    @Test("Weekend-only rider on a Tuesday")
    func weekendRiderOnTuesday() {
        var fixture = Fixture()
        fixture.windows = Fixture.weekendDays
        let tuesday = fixture.outlook[1]
        #expect(tuesday.hasNoScheduledWindow)
        #expect(
            tuesday.windows.map(\.interval) == [DateInterval(start: Fixture.at(day: 1, 6), end: Fixture.at(day: 1, 20))]
        )
    }

    // Scenario: ride-verdict: Afternoon check
    @Test("Afternoon check")
    func afternoonCheck() {
        var fixture = Fixture()
        fixture.windows = Fixture.weekendDays
        fixture.now = Fixture.at(14)
        fixture.sun = { day in (Fixture.at(day: day, 6), Fixture.at(day: day, 17, 30)) }
        #expect(fixture.today.windows[0].evaluatedHours == [14, 15, 16, 17].map { Fixture.at($0) })
    }

    // Scenario: ride-verdict: After sunset
    @Test("After sunset")
    func afterSunset() {
        var fixture = Fixture()
        fixture.windows = Fixture.weekendDays
        fixture.now = Fixture.at(18)
        fixture.sun = { day in (Fixture.at(day: day, 6), Fixture.at(day: day, 17, 30)) }
        #expect(fixture.today.status == .noDaylightRemaining)
        #expect(fixture.today.verdict == nil)
    }

    // Scenario: ride-verdict: Missing sun times
    @Test("Missing sun times")
    func missingSunTimes() {
        var fixture = Fixture()
        fixture.windows = Fixture.weekendDays
        fixture.sun = { day in day == 1 ? (nil, nil) : (Fixture.at(day: day, 6), Fixture.at(day: day, 20)) }
        #expect(fixture.outlook[1].verdict == .unknown)
        #expect(fixture.outlook[1].unknownReason == .missingSunTimes)
    }

    // Scenario: ride-verdict: Morning window already over
    @Test("Morning window already over")
    func morningWindowAlreadyOver() {
        var fixture = Fixture()
        fixture.now = Fixture.at(12)
        fixture.weather = { hour, _ in
            if [7, 8].contains(Fixture.hour(hour.start)) { hour.precipitationChance = 0.9 }
        }
        #expect(fixture.today.verdict == .ride)
        #expect(fixture.today.windows[0].isEnded)
        #expect(!fixture.today.windows[1].isEnded)
    }

    // Scenario: ride-verdict: All windows over
    @Test("All windows over")
    func allWindowsOver() {
        var fixture = Fixture()
        fixture.now = Fixture.at(19)
        #expect(fixture.today.status == .noRideWindowsRemaining)
        #expect(fixture.today.verdict == nil)
    }

    @Test func dstTransitionDayKeepsWallClockWindows() {
        // Sunday 8 March 2026 is the spring-forward day in New York.
        var fixture = Fixture()
        let sunday = Fixture.calendar.date(from: DateComponents(year: 2026, month: 3, day: 8))!
        fixture.now = Fixture.calendar.date(bySettingHour: 5, minute: 0, second: 0, of: sunday)!
        fixture.hoursStart = Fixture.calendar.date(byAdding: .day, value: -1, to: sunday)!
        fixture.hoursEnd = Fixture.calendar.date(byAdding: .day, value: 8, to: sunday)!
        fixture.windows = [RideWindow(weekdays: [1], from: (7, 0), to: (9, 0))]
        fixture.sun = { _ in (nil, nil) }
        let window = fixture.today.windows[0]
        #expect(window.evaluatedHours.map(Fixture.hour) == [7, 8])
        #expect(window.verdict == .ride)
    }
}
