import Foundation
import RiderSettings
import Testing
import VerdictEngine

@testable import Presentation
@testable import WeatherData

struct NotificationPlannerTests {
    static let on = NotificationSettings(isEnabled: true)

    static func plan(_ scene: Scene, settings: NotificationSettings = on) -> [PlannedNotification] {
        NotificationPlanner(formatter: scene.formatter).plan(
            settings: settings, profile: scene.profile, outlook: scene.outlook, fetchedAt: scene.fetchedAt ?? scene.now,
            now: scene.now)
    }

    /// The evening before Monday, when the app last fetched.
    static var sundayEvening: Scene {
        var scene = Scene()
        scene.now = Scene.at(day: -1, 21)
        return scene
    }

    // Scenario: ride-notifications: Ride morning
    @Test("Ride morning")
    func rideMorning() {
        let first = Self.plan(Self.sundayEvening).first
        #expect(first?.fireDate == Scene.at(6, 30))
        #expect(first?.body.hasPrefix("Ride: clear 7–9 AM and 4–6 PM.") == true)
    }

    // Scenario: ride-notifications: Maybe morning
    @Test("Maybe morning")
    func maybeMorning() {
        var scene = Scene()
        scene.now = Scene.at(day: 0, 5, 50)
        scene.weather = { hour, position in
            if position == .ring(.w, .outer), [16, 17].contains(Scene.hour(hour.start)),
                Scene.calendar.isDate(hour.start, inSameDayAs: Scene.at(12))
            {
                hour.windGust = Quantity.speed.si(fromDisplay: 34, in: .imperial)
            }
            if [
                .ring(.n, .outer), .ring(.ne, .outer), .ring(.e, .outer), .ring(.se, .outer), .ring(.sw, .outer),
                .ring(.nw, .outer),
            ]
            .contains(position), Scene.hour(hour.start) == 16 {
                hour.uvIndex = 9
            }
        }
        let body = Self.plan(scene).first?.body
        #expect(body == "Maybe: gusts up to 34 mph to the west, 4–6 PM. Clear to the south.")
    }

    // Scenario: ride-notifications: No background time granted
    @Test("No background time granted")
    func noBackgroundTimeGranted() {
        let planned = Self.plan(Self.sundayEvening)
        #expect(planned.count == 3)
        #expect(planned.map(\.fireDate) == [Scene.at(6, 30), Scene.at(day: 1, 6, 30), Scene.at(day: 2, 6, 30)])
        #expect(planned[0].body.contains("Ride: clear"))
    }

    // Scenario: ride-notifications: Last night's forecast
    @Test("Last night's forecast")
    func lastNightsForecast() {
        let body = Self.plan(Self.sundayEvening).first?.body
        #expect(body == "Ride: clear 7–9 AM and 4–6 PM. Based on last night's forecast.")
    }

    // Scenario: ride-notifications: Too old
    @Test("Too old")
    func tooOld() {
        let planned = Self.plan(Self.sundayEvening)
        #expect(planned[1].body == NotificationPlanner.tooOldBody)
        #expect(planned[2].body == NotificationPlanner.tooOldBody)
        #expect(!planned[1].body.contains("Ride:"))
    }

    @Test func freshForecastHasNoAgeNote() {
        var scene = Scene()
        scene.now = Scene.at(5, 20)
        #expect(Self.plan(scene).first?.body == "Ride: clear 7–9 AM and 4–6 PM.")
    }

    @Test func offOrPastTimesPlanNothingForThem() {
        #expect(Self.plan(Scene(), settings: NotificationSettings(isEnabled: false)).isEmpty)
        var afterSix = Scene()
        afterSix.now = Scene.at(7)
        #expect(Self.plan(afterSix).first?.fireDate == Scene.at(day: 1, 6, 30))
    }

    @Test func customDaysAreRespected() {
        let settings = NotificationSettings(isEnabled: true, days: .custom([7]))
        #expect(
            Self.plan(Scene(), settings: settings).map(\.fireDate) == [
                Scene.at(day: 5, 6, 30), Scene.at(day: 12, 6, 30), Scene.at(day: 19, 6, 30),
            ])
    }
}
