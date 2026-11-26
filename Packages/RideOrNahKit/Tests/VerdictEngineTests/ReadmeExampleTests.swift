import Foundation
import Testing
import VerdictEngine

/// The worked example in Sources/VerdictEngine/README.md, verbatim. Uses only the public API.
struct ReadmeExampleTests {
    @Test func workedExampleMatchesTheReadme() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        let monday = calendar.date(from: DateComponents(year: 2026, month: 6, day: 8, hour: 6))!

        func hours(gustAt8: Double) -> [HourConditions] {
            (0..<4).map { offset in
                let start = monday.addingTimeInterval(Double(offset + 1) * 3600)  // 07:00 to 10:00
                return HourConditions(
                    start: start, temperature: 20, feelsLike: 20, humidity: 0.5, windSpeed: 4,
                    windGust: offset == 1 ? gustAt8 : 6, uvIndex: 3, visibility: 10_000,
                    precipitationChance: 0, precipitationIntensity: 0)
            }
        }

        let input = EvaluationInput(
            now: monday, calendar: calendar,
            profile: ProfileSnapshot(
                limits: Limits(gusts: ThresholdLimit(soft: 13.4, hard: 17.9)),
                windows: [RideWindow(weekdays: [2], from: (7, 0), to: (9, 0))]),
            samples: [
                SampleForecast(position: .center, hours: hours(gustAt8: 6)),
                SampleForecast(position: .ring(.w, .outer), hours: hours(gustAt8: 15.2)),
            ],
            sun: [], fetchedAt: monday)

        let today = VerdictEngine.outlook(for: input)[0]
        #expect(today.verdict == .maybe)
        #expect(today.breaches.count == 1)
        let breach = today.breaches[0]
        #expect(breach.factor == .gusts)
        #expect(breach.severity == .soft)
        #expect(breach.worstValue == 15.2)
        #expect(breach.limit == 13.4)
        #expect(breach.range == DateInterval(start: monday.addingTimeInterval(2 * 3600), duration: 3600))
        #expect(breach.positions == [.ring(.w, .outer)])
        #expect(today.clearDirections == [])
    }
}
