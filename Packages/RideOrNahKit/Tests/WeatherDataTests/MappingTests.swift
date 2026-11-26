import Foundation
import Testing
import VerdictEngine
import WeatherKit

@testable import WeatherData

struct MappingTests {
    @Test(arguments: WeatherCondition.allCases)
    func everyConditionHasAMapping(condition: WeatherCondition) {
        let expected: HazardFlags =
            switch condition {
            case .isolatedThunderstorms, .scatteredThunderstorms, .strongStorms, .thunderstorms, .tropicalStorm,
                .hurricane:
                .thunderstorm
            case .hail: .hail
            case .blizzard, .blowingSnow, .flurries, .freezingDrizzle, .freezingRain, .heavySnow, .sleet, .snow,
                .sunFlurries, .wintryMix:
                .frozenPrecipitation
            case .foggy: .fog
            default: []
            }
        #expect(ConditionMapper.hazards(for: condition) == expected)
    }

    @Test func severitiesMapOneToOneAndUnknownCountsAsModerate() {
        #expect(ConditionMapper.severity(.minor) == .minor)
        #expect(ConditionMapper.severity(.moderate) == .moderate)
        #expect(ConditionMapper.severity(.severe) == .severe)
        #expect(ConditionMapper.severity(.extreme) == .extreme)
        #expect(ConditionMapper.severity(.unknown) == .moderate)
    }

    @Test func errorsMapToWhatTheRiderIsTold() {
        #expect(ConditionMapper.sourceError(WeatherError.permissionDenied) == .notAuthorized)
        #expect(ConditionMapper.sourceError(URLError(.notConnectedToInternet)) == .offline)
        #expect(ConditionMapper.sourceError(URLError(.badServerResponse)) == .serviceUnavailable)
    }

    @Test(arguments: FixtureProvider.Scenario.allCases)
    func everyFixtureScenarioLoads(scenario: FixtureProvider.Scenario) async throws {
        let provider = FixtureProvider(scenario: scenario, center: TestTime.newYork, calendar: TestTime.calendar)
        let day = DateInterval(start: TestTime.morning, duration: 86_400)
        let forecast = try await provider.forecast(
            at: RoundedCoordinate(TestTime.newYork), hours: day, days: day)
        #expect(forecast.hours.count == 24)
        #expect(forecast.days.first?.sunrise != nil)
        #expect(!provider.makesNetworkRequests)
    }

    @Test func stormFixtureFlagsOnlyNorthernPoints() async throws {
        let provider = FixtureProvider(
            scenario: .stormToTheNorth, center: TestTime.newYork, calendar: TestTime.calendar)
        let day = DateInterval(start: TestTime.morning, duration: 3600)
        var stormy: [SamplePosition] = []
        for point in SampleLayout.points(center: TestTime.newYork, radius: 40_000) {
            let forecast = try await provider.forecast(at: point.coordinate, hours: day, days: day)
            if forecast.hours.contains(where: { $0.hazards.contains(.thunderstorm) }) { stormy.append(point.position) }
        }
        #expect(stormy == [.ring(.n, .outer), .ring(.ne, .outer), .ring(.nw, .outer)])
    }

    @Test func fixtureSnapshotEvaluatesThroughTheEngine() async throws {
        let store = ForecastStore(
            provider: FixtureProvider(scenario: .afternoonRain, center: TestTime.newYork, calendar: TestTime.calendar),
            cache: ForecastCache(directory: FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)),
            budget: nil, calendar: TestTime.calendar, clock: { TestTime.morning })
        let snapshot = await store.snapshot(center: TestTime.newYork, radius: 40_000, purpose: .foreground)
        #expect(snapshot.networkRequests == 0)
        let commute = [
            RideWindow(weekdays: [2], from: (7, 0), to: (9, 0)), RideWindow(weekdays: [2], from: (16, 0), to: (18, 0)),
        ]
        let profile = ProfileSnapshot(
            limits: Limits(precipitation: PrecipitationLimit(chance: ThresholdLimit(soft: 0.3, hard: 0.6))),
            windows: commute)
        let input = try #require(
            snapshot.evaluationInput(profile: profile, now: TestTime.morning, calendar: TestTime.calendar))
        let today = VerdictEngine.outlook(for: input)[0]
        #expect(today.windows.map(\.verdict) == [.ride, .nah])
        #expect(today.verdict == .nah)
    }
}
