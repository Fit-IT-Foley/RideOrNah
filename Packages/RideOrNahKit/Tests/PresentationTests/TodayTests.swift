import Foundation
import RiderSettings
import Testing
import VerdictEngine

@testable import Presentation
@testable import WeatherData

struct TodayTests {
    // Scenario: verdict-display: Nah from rain
    @Test("Nah from rain")
    func nahFromRain() {
        var scene = Scene()
        scene.profile.windows = [RideWindow(weekdays: [2], from: (16, 0), to: (19, 0))]
        scene.weather = { hour, _ in
            if [17, 18].contains(Scene.hour(hour.start)) { hour.precipitationChance = 0.7 }
        }
        let today = scene.today
        #expect(today.word == "NAH")
        #expect(today.summary == "Rain likely 5–7 PM (70%)")
    }

    // Scenario: verdict-display: Clean day
    @Test("Clean day")
    func cleanDay() {
        let today = Scene().today
        #expect(today.word == "RIDE")
        #expect(today.summary == "Clear for all your ride windows")
        #expect(today.reasons.isEmpty)
    }

    // Scenario: verdict-display: Done for today
    @Test("Done for today")
    func doneForToday() {
        var scene = Scene()
        scene.now = Scene.at(19)
        let today = scene.today
        #expect(today.verdict == nil)
        #expect(today.summary == "Today's riding windows are over")
        #expect(today.tomorrow?.weekday == "Tue")
        #expect(today.tomorrow?.verdict == .ride)
    }

    // Scenario: verdict-display: Anytime rider
    @Test("Anytime rider")
    func anytimeRider() {
        var scene = Scene()
        scene.profile.windows = []
        let today = scene.today
        #expect(today.note == nil)
        #expect(today.windows.map(\.timeRange) == ["6 AM–8 PM"])
        var weekendRider = Scene()
        weekendRider.profile.windows = RidingStyle.weekends.windows
        #expect(weekendRider.today.note == "No ride planned today · judged on daylight")
    }

    // Scenario: verdict-display: Gust reason
    @Test("Gust reason")
    func gustReason() {
        var scene = Scene()
        scene.profile.windows = [RideWindow(weekdays: [2], from: (16, 0), to: (19, 0))]
        let gusts: [Int: Double] = [16: 32, 17: 34, 18: 31]
        scene.weather = { hour, position in
            if position == .ring(.w, .outer), let mph = gusts[Scene.hour(hour.start)],
                Scene.calendar.isDate(hour.start, inSameDayAs: Scene.at(12))
            {
                hour.windGust = Quantity.speed.si(fromDisplay: mph, in: .imperial)
            }
        }
        let reason = scene.today.reasons.first
        #expect(reason?.severity == .soft)
        #expect(reason?.title == "Gusts up to 34 mph")
        #expect(reason?.limit == "(your limit 30 mph)")
        #expect(reason?.detail == "4–7 PM · to the west")
    }

    // Scenario: verdict-display: Clear to the south
    @Test("Clear to the south")
    func clearToTheSouth() {
        var scene = Scene()
        scene.weather = { hour, position in
            if [.ring(.n, .outer), .ring(.ne, .outer), .ring(.nw, .outer)].contains(position) {
                hour.precipitationChance = 0.9
            }
        }
        #expect(scene.today.directionText == "Clear to the E, SE, S, SW and W")
    }

    // Scenario: verdict-display: Bad everywhere
    @Test("Bad everywhere")
    func badEverywhere() {
        var scene = Scene()
        scene.weather = { hour, _ in hour.precipitationChance = 0.9 }
        #expect(scene.today.directionText == "No direction in 25 mi is clear")
    }

    @Test func noDirectionTextOnRideOrLocal() {
        #expect(Scene().today.directionText == nil)
        var local = Scene()
        local.radius = .local
        local.positions = [.center]
        local.weather = { hour, _ in hour.precipitationChance = 0.9 }
        #expect(local.today.directionText == nil)
    }

    // Scenario: verdict-display: Stale verdict
    @Test("Stale verdict")
    func staleVerdict() {
        var scene = Scene()
        scene.fetchedAt = scene.now.addingTimeInterval(-5 * 3600)
        let today = scene.today
        #expect(today.staleNote == "Based on an older forecast")
        #expect(today.freshness == "Home · Mon 8 Jun · Updated 5 hours ago")
        #expect(today.word == "RIDE")
    }

    // Scenario: verdict-display: Partial coverage
    @Test("Partial coverage")
    func partialCoverage() {
        var scene = Scene()
        scene.failed = [.ring(.sw, .outer)]
        #expect(scene.today.notes.contains("Couldn't check the southwest"))
    }

    // Scenario: verdict-display: Offline first launch
    @Test("Offline first launch")
    func offlineFirstLaunch() {
        let scene = Scene()
        let snapshot = ForecastSnapshot(
            samples: [], sun: [], alerts: [], alertsUnavailable: [], fetchedAt: nil, outcome: .offline,
            networkRequests: 0)
        let today = TodayPresenter(formatter: scene.formatter).content(
            outlook: nil, snapshot: snapshot, place: scene.place, profile: scene.profile, radius: scene.radius,
            now: scene.now)
        #expect(today.word == "CAN'T TELL")
        #expect(![Verdict.ride, .maybe, .nah].contains(today.verdict))
        #expect(today.unknown?.cause == .offline)
        #expect(today.unknown?.action == "Try again")
    }

    @Test func everyUnknownCauseHasWords() {
        let scene = Scene()
        let presenter = TodayPresenter(formatter: scene.formatter)
        let noPlace = presenter.content(
            outlook: nil, snapshot: nil, place: nil, profile: scene.profile, radius: scene.radius, now: scene.now)
        #expect(noPlace.unknown?.cause == .noLocation)
        #expect(noPlace.unknown?.action == "Add a place")
        var old = Scene()
        old.fetchedAt = old.now.addingTimeInterval(-13 * 3600)
        #expect(old.today.unknown?.cause == .forecastTooOld)
        for outcome in [ForecastOutcome.notAuthorized, .serviceUnavailable, .budgetLimited] {
            let snapshot = ForecastSnapshot(
                samples: [], sun: [], alerts: [], alertsUnavailable: [], fetchedAt: nil, outcome: outcome,
                networkRequests: 0)
            let content = presenter.content(
                outlook: nil, snapshot: snapshot, place: scene.place, profile: scene.profile, radius: scene.radius,
                now: scene.now)
            #expect(content.word == "CAN'T TELL")
            #expect(!(content.unknown?.title.isEmpty ?? true))
        }
    }

    // Scenario: verdict-display: Current hour values
    @Test("Current hour values")
    func currentHourValues() {
        var scene = Scene()
        scene.weather = { hour, position in
            if position == .center && hour.start == Scene.at(6) {
                hour.temperature = 12.2
                hour.feelsLike = 10.6
                hour.precipitationChance = 0.8
            }
        }
        #expect(scene.today.current == CurrentConditions(air: "54°", feelsLike: "51°", rainChance: "80%"))
    }

    // Scenario: verdict-display: Comfortable margins
    @Test("Comfortable margins")
    func comfortableMargins() {
        let today = Scene().today
        #expect(today.word == "RIDE")
        #expect(today.room.first == RoomRow(title: "Rain chance", worst: "0%", maybeAt: "Maybe at 30%"))
        #expect(today.room.map(\.title) == ["Rain chance", "Gusts", "Coldest hour", "UV index"])
    }

    // Scenario: verdict-display: Sun times
    @Test("Sun times")
    func sunTimes() {
        var scene = Scene()
        scene.sunrise = (6, 38)
        scene.sunset = (16, 46)
        #expect(scene.today.daylight == DaylightContent(sunrise: "6:38 AM", sunset: "4:46 PM", length: "10h 08m"))
    }

    @Test func notesForBudgetAndMissingAlerts() {
        var scene = Scene()
        scene.outcome = .budgetLimited
        #expect(scene.today.notes.contains("Refreshing is paused until tomorrow"))
    }
}
