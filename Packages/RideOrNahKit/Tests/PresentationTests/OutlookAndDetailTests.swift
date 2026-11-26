import Foundation
import RiderSettings
import Testing
import VerdictEngine

@testable import Presentation
@testable import WeatherData

struct OutlookAndDetailTests {
    // Scenario: verdict-display: Outlook confidence marker
    @Test("Outlook confidence marker")
    func outlookConfidenceMarker() {
        let scene = Scene()
        let rows = OutlookPresenter(formatter: scene.formatter).rows(
            scene.outlook, profile: scene.profile, now: scene.now)
        #expect(rows.map(\.lowerConfidence) == [false, false, false, true, true, true, true])
        #expect(rows.first?.detail == "Today")
        #expect(rows[1].weekday == "Tue")
        #expect(rows[1].detail == "9 Jun")
        #expect(rows[5].summary == "No ride window scheduled · clear in daylight")
    }

    // Scenario: verdict-display: Hour with a breach
    @Test("Hour with a breach")
    func hourWithABreach() {
        var scene = Scene()
        scene.profile.windows = [RideWindow(weekdays: [2], from: (16, 0), to: (18, 0))]
        scene.weather = { hour, position in
            if position == .center && hour.start == Scene.at(17) { hour.precipitationChance = 0.8 }
        }
        let detail = DayDetailPresenter(formatter: scene.formatter).content(
            scene.outlook[0], snapshot: scene.snapshot, profile: scene.profile, now: scene.now)
        let hours = detail.sections[0].hours
        #expect(hours.map(\.hour) == ["4 PM", "5 PM"])
        #expect(hours[0].marks.isEmpty)
        #expect(hours[1].marks.map(\.severity) == [.hard])
        #expect(hours[1].marks.map(\.text) == ["Rain chance 80% here"])
        #expect(detail.title == "Monday 8 Jun")
    }

    // Scenario: verdict-display: Missing value in the detail
    @Test("Missing value in the detail")
    func missingValueInTheDetail() {
        var scene = Scene()
        scene.profile.windows = [RideWindow(weekdays: [2], from: (16, 0), to: (18, 0))]
        scene.weather = { hour, position in
            if position == .center && hour.start == Scene.at(17) { hour.uvIndex = nil }
        }
        let detail = DayDetailPresenter(formatter: scene.formatter).content(
            scene.outlook[0], snapshot: scene.snapshot, profile: scene.profile, now: scene.now)
        #expect(detail.sections[0].hours[1].uv == "—")
        #expect(detail.sections[0].hours[0].uv == "3")
    }

    @Test func formatterCoversBothUnitSystems() {
        let imperial = DisplayFormatter(units: .imperial, calendar: Scene.calendar)
        let metric = DisplayFormatter(units: .metric, calendar: Scene.calendar)
        #expect(imperial.temperature(12.2) == "54°")
        #expect(metric.temperature(12.2) == "12°")
        #expect(imperial.speed(13.41) == "30 mph")
        #expect(metric.speed(13.41) == "48 km/h")
        #expect(imperial.distance(1287) == "0.8 mi")
        #expect(metric.distance(1287) == "1.3 km")
        #expect(imperial.rate(1) == "0.04 in/h")
        #expect(metric.rate(1) == "1.0 mm/h")
        #expect(imperial.timeRange(DateInterval(start: Scene.at(16), end: Scene.at(19))) == "4–7 PM")
        #expect(imperial.timeRange(DateInterval(start: Scene.at(11), end: Scene.at(17, 30))) == "11 AM–5:30 PM")
        #expect(imperial.relative(DateInterval(start: Scene.at(16), end: Scene.at(18)), now: Scene.at(8)) == "In 8 h")
        #expect(imperial.relative(DateInterval(start: Scene.at(7), end: Scene.at(9)), now: Scene.at(8)) == "Now")
        #expect(imperial.age(12 * 60) == "12 min ago")
        #expect(imperial.places([.center]) == "here")
        #expect(imperial.places([.ring(.w, .outer)]) == "to the west")
        #expect(
            imperial.places([.center, .ring(.n, .outer), .ring(.ne, .inner), .ring(.nw, .outer)])
                == "here and to the N, NE and NW")
    }
}
