import Foundation
import RiderSettings
import Testing
import VerdictEngine

@testable import Presentation
@testable import WeatherData

struct SuggestionTests {
    /// Saturday is clear from 11:00 until sunset at 17:30, with rain before.
    static var saturday: Scene {
        var scene = Scene()
        scene.sunset = (17, 30)
        scene.weather = { hour, _ in
            if Scene.calendar.isDate(hour.start, inSameDayAs: Scene.at(day: 5, 12)), Scene.hour(hour.start) < 11 {
                hour.precipitationChance = 0.9
            }
        }
        return scene
    }

    static let afternoon = DateInterval(start: Scene.at(day: 5, 11), end: Scene.at(day: 5, 17, 30))

    static func suggestions(_ scene: Scene, isOn: Bool = true, added: [AddedRide] = [], fetchedAt: Date? = nil)
        -> [RideSuggestion]
    {
        let day = scene.outlook.first { Scene.calendar.isDate($0.day, inSameDayAs: Scene.at(day: 5, 12)) }!
        return SuggestionPresenter(formatter: scene.formatter).suggestions(
            for: day, isOn: isOn, added: added, fetchedAt: fetchedAt ?? scene.now, now: scene.now)
    }

    // Scenario: ride-calendar: Default off
    @Test("Default off")
    func defaultOff() {
        let preferences = Preferences(firstProfile: RiderProfile.defaults(named: "My Bike", style: .commute))
        #expect(preferences.rideSuggestions == false)
        let scene = Self.saturday
        for day in scene.outlook {
            #expect(
                SuggestionPresenter(formatter: scene.formatter).suggestions(
                    for: day, isOn: preferences.rideSuggestions, added: [], fetchedAt: scene.now, now: scene.now
                ).isEmpty)
        }
    }

    // Scenario: ride-calendar: Clear Saturday afternoon
    @Test("Clear Saturday afternoon")
    func clearSaturdayAfternoon() {
        let first = Self.suggestions(Self.saturday).first
        #expect(first?.range == Self.afternoon)
        #expect(first?.text == "11 AM–5:30 PM")
        #expect(first?.isAdded == false)
        #expect(first?.lowerConfidence == true)
    }

    // Scenario: ride-calendar: Stale forecast
    @Test("Stale forecast")
    func staleForecast() {
        let scene = Self.saturday
        #expect(Self.suggestions(scene, fetchedAt: scene.now.addingTimeInterval(-3 * 3600 - 60)).isEmpty)
        #expect(!Self.suggestions(scene, fetchedAt: scene.now.addingTimeInterval(-2 * 3600)).isEmpty)
    }

    // Scenario: ride-calendar: Already added
    @Test("Already added")
    func alreadyAdded() {
        let added = [AddedRide(range: Self.afternoon, profileName: "Commuter", placeName: "Home")]
        let first = Self.suggestions(Self.saturday, added: added).first
        #expect(first?.text == "11 AM–5:30 PM")
        #expect(first?.isAdded == true)
    }

    @Test("Calendar draft")
    func calendarDraft() {
        let scene = Self.saturday
        let draft = CalendarDraft(
            range: Self.afternoon, profileName: "Commuter", placeName: "Home", radius: .km40, fetchedAt: Scene.at(6),
            formatter: scene.formatter)
        #expect(draft.title == "Ride · Commuter")
        #expect(draft.range == Self.afternoon)
        #expect(draft.location == "Home")
        #expect(
            draft.notes
                == "Clear at every point in 25 mi.\nForecast from 6 AM, Mon 8 Jun.\nCheck Ride or Nah before you leave."
        )
        let local = CalendarDraft(
            range: Self.afternoon, profileName: "Commuter", placeName: "Home", radius: .local, fetchedAt: Scene.at(6),
            formatter: scene.formatter)
        #expect(local.notes.hasPrefix("Clear at Home."))
    }

    // Scenario: ride-calendar: Rain moves in
    @Test("Rain moves in")
    func rainMovesIn() throws {
        var scene = Scene()
        scene.weather = { hour, _ in
            if hour.start == Scene.at(day: 5, 15) { hour.precipitationChance = 0.9 }
        }
        let input = try #require(
            scene.snapshot.evaluationInput(profile: scene.profile.snapshot, now: scene.now, calendar: Scene.calendar))
        let ride = AddedRide(range: Self.afternoon, profileName: "Commuter", placeName: "Home")
        let status = AddedRideCheck(formatter: scene.formatter).status(
            ride, evaluation: VerdictEngine.evaluate(range: ride.range, in: input))
        #expect(status.state == .warning("Your Saturday ride now looks like Nah: rain likely from 3 PM (90%)."))
    }

    // Scenario: ride-calendar: Can't check an added ride
    @Test("Can't check an added ride")
    func cantCheckAnAddedRide() throws {
        var scene = Scene()
        scene.fetchedAt = Scene.at(day: 3, 6)
        scene.now = Scene.at(day: 5, 9)
        let input = try #require(
            scene.snapshot.evaluationInput(profile: scene.profile.snapshot, now: scene.now, calendar: Scene.calendar))
        let ride = AddedRide(range: Self.afternoon, profileName: "Commuter", placeName: "Home")
        let evaluation = VerdictEngine.evaluate(range: ride.range, in: input)
        #expect(evaluation.verdict == .unknown)
        let status = AddedRideCheck(formatter: scene.formatter).status(ride, evaluation: evaluation)
        #expect(status.state == .notChecked)
    }

    // Scenario: ride-calendar: Morning action
    @Test("Morning action")
    func morningAction() {
        var scene = Scene()
        scene.now = Scene.at(5, 50)
        scene.weather = { hour, _ in
            let clock = Scene.hour(hour.start)
            if Scene.calendar.isDate(hour.start, inSameDayAs: Scene.at(12)), clock < 10 || clock >= 15 {
                hour.precipitationChance = 0.9
            }
        }
        let planned = NotificationPlanner(formatter: scene.formatter).plan(
            settings: NotificationSettings(isEnabled: true, days: .everyDay), profile: scene.profile,
            outlook: scene.outlook, fetchedAt: scene.now, now: scene.now, suggestions: true)
        #expect(planned.first?.calendarRange == DateInterval(start: Scene.at(10), end: Scene.at(15)))
        let off = NotificationPlanner(formatter: scene.formatter).plan(
            settings: NotificationSettings(isEnabled: true, days: .everyDay), profile: scene.profile,
            outlook: scene.outlook, fetchedAt: scene.now, now: scene.now, suggestions: false)
        #expect(off.first?.calendarRange == nil)
    }

    // Scenario: ride-calendar: Old forecast, no action
    @Test("Old forecast, no action")
    func oldForecastNoAction() {
        var scene = Scene()
        scene.now = Scene.at(day: -1, 21)
        let planned = NotificationPlanner(formatter: scene.formatter).plan(
            settings: NotificationSettings(isEnabled: true, days: .everyDay), profile: scene.profile,
            outlook: scene.outlook, fetchedAt: scene.now, now: scene.now, suggestions: true)
        #expect(planned.count == 3)
        #expect(planned.allSatisfy { $0.calendarRange == nil })
    }
}
