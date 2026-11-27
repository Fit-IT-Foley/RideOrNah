import Foundation
import RiderSettings
import Testing
import VerdictEngine

@testable import Presentation
@testable import WeatherData

struct WatchTests {
    /// Results as the iPhone would send them from `scene`, fetched at `scene.now`.
    static func results(_ scene: Scene, hasAccess: Bool = true) -> WatchResults {
        WatchResults.make(
            outlook: scene.outlook, fetchedAt: scene.fetchedAt ?? scene.now, hasAccess: hasAccess,
            profile: scene.profile, placeName: "Home", radius: scene.radius, formatter: scene.formatter)
    }

    static func content(_ results: WatchResults?, at now: Date) -> WatchContent {
        WatchPresenter(formatter: Scene().formatter).content(results, now: now)
    }

    /// Rain at `hour` on Monday (day 0) or another day.
    static func rain(day: Int = 0, at hours: Set<Int>) -> Scene {
        var scene = Scene()
        scene.weather = { hour, _ in
            if Scene.calendar.isDate(hour.start, inSameDayAs: Scene.at(day: day, 12)),
                hours.contains(Scene.hour(hour.start))
            {
                hour.precipitationChance = 0.9
            }
        }
        return scene
    }

    // Scenario: watch-app: Showing received results
    @Test("Showing received results")
    func showingReceivedResults() {
        let results = Self.results(Self.rain(at: [16]))
        let content = Self.content(results, at: Scene.at(6, 30))
        #expect(content.state == .verdict)
        #expect(content.label == "Today")
        #expect(content.word == "NAH")
        #expect(content.windows.map(\.text) == ["7–9 AM", "4–6 PM"])
        #expect(content.windows.map(\.verdict) == [.ride, .nah])
        #expect(content.reasons == ["Rain likely 4–5 PM (90%)"])
        #expect(content.profileName == "Commuter")
        #expect(content.placeName == "Home")
        #expect(content.days.count == 6)
        #expect(content.days.map(\.lowerConfidence) == [false, false, true, true, true, true])
    }

    // Scenario: watch-app: Rectangular complication
    @Test("Rectangular complication")
    func rectangularComplication() {
        let content = Self.content(Self.results(Self.rain(at: [17])), at: Scene.at(6, 30))
        #expect(content.word == "NAH")
        #expect(content.verdict.map(VerdictWords.spoken) == "Nah")
        #expect(content.reason.contains("Rain"))
        #expect(content.reason.contains("5"))
        #expect(content.reason.contains("PM"))
    }

    // Scenario: watch-app: Past midnight with no update
    @Test("Past midnight with no update")
    func pastMidnightWithNoUpdate() {
        var scene = Self.rain(day: 1, at: [8])
        scene.now = Scene.at(21)
        let results = Self.results(scene)
        #expect(Self.content(results, at: Scene.at(21, 30)).label == "Tomorrow")
        let afterMidnight = Self.content(results, at: Scene.at(day: 1, 1))
        #expect(afterMidnight.label == "Today")
        #expect(afterMidnight.word == "NAH")
        #expect(afterMidnight.days.first?.weekday == "Wed")
    }

    // Scenario: watch-app: Evening on the watch
    @Test("Evening on the watch")
    func eveningOnTheWatch() {
        var scene = Self.rain(day: 1, at: [8])
        scene.now = Scene.at(17)
        let results = Self.results(scene)
        #expect(Self.content(results, at: Scene.at(17, 30)).label == "Today")
        let evening = Self.content(results, at: Scene.at(18, 1))
        #expect(evening.label == "Tomorrow")
        #expect(evening.word == "NAH")
    }

    @Test("A window ending changes the call")
    func windowEnding() {
        let results = Self.results(Self.rain(at: [8]))
        #expect(Self.content(results, at: Scene.at(6, 30)).word == "NAH")
        let later = Self.content(results, at: Scene.at(9, 30))
        #expect(later.word == "RIDE")
        #expect(later.windows.map(\.text) == ["4–6 PM"])
        #expect(later.reason == "Clear for the rest of your windows")
    }

    // Scenario: watch-app: Phone left at home
    @Test("Phone left at home")
    func phoneLeftAtHome() {
        let results = Self.results(Scene())
        let content = Self.content(results, at: Scene.at(19, 1))
        #expect(content.state == .needsPhone)
        #expect(content.word == nil)
        #expect(content.reason == "Open Ride or Nah on your iPhone.")
        #expect(Self.content(nil, at: Scene.at(6)).state == .needsPhone)
    }

    // Scenario: watch-app: Lapsed subscription
    @Test("Lapsed subscription")
    func lapsedSubscription() {
        let content = Self.content(Self.results(Scene(), hasAccess: false), at: Scene.at(6, 30))
        #expect(content.state == .locked)
        #expect(content.word == nil)
        #expect(content.windows.isEmpty)
        #expect(content.reason == "Subscribe on your iPhone to see the call.")
    }

    // Scenario: watch-app: Complication ages without an update
    @Test("Complication ages without an update")
    func complicationAgesWithoutAnUpdate() {
        var scene = Scene()
        scene.profile = RiderProfile.defaults(named: "Anytime", style: .anytime)
        let results = Self.results(scene)
        let dates = WatchTimeline.entryDates(results, now: Scene.at(6), calendar: Scene.calendar)
        #expect(dates.contains(Scene.at(9)))
        #expect(dates.contains(Scene.at(18)))
        #expect(dates.contains(Scene.at(day: 1, 0)))
        #expect(Self.content(results, at: Scene.at(8)).isStale == false)
        #expect(Self.content(results, at: Scene.at(9, 1)).isStale)
        #expect(Self.content(results, at: Scene.at(9, 1)).word == "RIDE")
        #expect(Self.content(results, at: Scene.at(18, 1)).word == nil)
    }

    @Test("Results round-trip as JSON")
    func codable() throws {
        let results = Self.results(Self.rain(at: [16]))
        let data = try JSONEncoder().encode(results)
        #expect(try JSONDecoder().decode(WatchResults.self, from: data) == results)
        #expect(data.count < 32_000)
    }
}
