import Foundation
import Testing
import VerdictEngine

@testable import RiderSettings

struct ProfileTests {
    // Scenario: rider-profiles: Fresh profile
    @Test("Fresh profile")
    func freshProfile() {
        var preferences = SettingsFixtures.preferences()
        let profile = preferences.addProfile(named: "Adventure")
        #expect(profile.limits == .defaults)
        #expect(profile.limits.precipitation.chance == ThresholdLimit(soft: 0.3, hard: 0.6))
        #expect(profile.limits.ice.threshold == 3)
        #expect(profile.limits.humidity.isEnabled == false)
        #expect(profile.minimumRideDuration == 2 * 3600)
        #expect(profile.radius == .km40)
    }

    // Scenario: rider-profiles: Reset to defaults
    @Test("Reset to defaults")
    func resetToDefaults() {
        var profile = RiderProfile.defaults(named: "Sport", style: .weekends)
        profile.limits.gusts.soft = 5
        profile.radius = .km160
        profile.resetLimits()
        #expect(profile.limits == .defaults)
        #expect(profile.name == "Sport")
        #expect(profile.windows == RidingStyle.weekends.windows)
        #expect(profile.radius == .km160)
    }

    // Scenario: rider-profiles: Anytime preset
    @Test("Anytime preset")
    func anytimePreset() {
        #expect(RiderProfile.defaults(named: "Any", style: .anytime).windows.isEmpty)
    }

    // Scenario: rider-profiles: Switching bikes
    @Test("Switching bikes")
    func switchingBikes() throws {
        var preferences = SettingsFixtures.preferences(["Commuter", "Adventure"])
        var adventure = preferences.profiles[1]
        adventure.radius = .km160
        adventure.windows = RidingStyle.weekends.windows
        adventure.limits.gusts.hard = 22
        preferences.update(adventure)
        try preferences.activate(adventure.id)
        let settings = preferences.evaluationSettings(
            now: SettingsFixtures.morning, calendar: SettingsFixtures.calendar)
        #expect(settings.radius == .km160)
        #expect(settings.profile.windows == RidingStyle.weekends.windows)
        #expect(settings.profile.limits.gusts.hard == 22)
    }

    // Scenario: rider-profiles: Deleting the last profile
    @Test("Deleting the last profile")
    func deletingTheLastProfile() {
        var preferences = SettingsFixtures.preferences()
        #expect(!preferences.canDeleteProfiles)
        #expect(throws: ProfileError.lastProfile) { try preferences.deleteProfile(preferences.profiles[0].id) }
        #expect(preferences.profiles.count == 1)
    }

    // Scenario: rider-profiles: Deleting the active profile
    @Test("Deleting the active profile")
    func deletingTheActiveProfile() throws {
        var preferences = SettingsFixtures.preferences(["Commuter", "Adventure", "Track"])
        let (commuter, adventure, track) = (
            preferences.profiles[0].id, preferences.profiles[1].id, preferences.profiles[2].id
        )
        try preferences.activate(track)
        try preferences.activate(adventure)
        try preferences.deleteProfile(adventure)
        #expect(preferences.activeProfileID == track)
        #expect(!preferences.profiles.contains { $0.id == adventure })
        #expect(preferences.profiles.map(\.id) == [commuter, track])
    }

    @Test func duplicatingAndRenamingKeepTheRest() {
        var preferences = SettingsFixtures.preferences()
        let copy = preferences.duplicate(preferences.profiles[0].id)!
        preferences.rename(copy.id, to: "Winter")
        #expect(preferences.profile(copy.id)?.name == "Winter")
        #expect(preferences.profile(copy.id)?.windows == preferences.profiles[0].windows)
    }

    // Scenario: rider-profiles: Soft beyond hard
    @Test("Soft beyond hard")
    func softBeyondHard() {
        var profile = RiderProfile.defaults(named: "Sport")
        profile.limits.gusts = ThresholdLimit(
            soft: Quantity.speed.si(fromDisplay: 45, in: .imperial),
            hard: Quantity.speed.si(fromDisplay: 40, in: .imperial))
        let problems = LimitValidator.problems(in: profile)
        #expect(problems.map(\.field) == [.gusts])
        #expect(problems.first?.message == "The soft limit must be lower than the hard limit.")
    }

    @Test func lowerIsWorseLimitsFlipTheRule() {
        var profile = RiderProfile.defaults(named: "Sport")
        profile.limits.cold = ThresholdLimit(soft: 2, hard: 5)
        #expect(
            LimitValidator.problems(in: profile).first?.message == "The soft limit must be higher than the hard limit.")
    }

    @Test func outOfRangeValuesAreRejected() {
        var profile = RiderProfile.defaults(named: "Sport")
        profile.limits.uv.soft = 40
        profile.limits.wetRoads.duration = 13 * 3600
        profile.minimumRideDuration = 10 * 60
        #expect(LimitValidator.problems(in: profile).map(\.field) == [.uv, .wetRoadsDuration, .minimumRideDuration])
        #expect(LimitValidator.problems(in: .defaults(named: "Fine")).isEmpty)
    }

    // Scenario: rider-profiles: Clearing a hard limit
    @Test("Clearing a hard limit")
    func clearingAHardLimit() {
        var limits = Limits.defaults
        limits.uv = ThresholdLimit(soft: 8, hard: 12)
        limits.uv.hard = nil
        let start = SettingsFixtures.morning.addingTimeInterval(3600)
        let hour = HourConditions(
            start: start, temperature: 20, feelsLike: 20, humidity: 0.5, windSpeed: 3, windGust: 5, uvIndex: 14,
            visibility: 10_000, precipitationChance: 0, precipitationIntensity: 0)
        let input = EvaluationInput(
            now: SettingsFixtures.morning, calendar: SettingsFixtures.calendar,
            profile: ProfileSnapshot(limits: limits, windows: [RideWindow(weekdays: [2], from: (7, 0), to: (8, 0))]),
            samples: [SampleForecast(position: .center, hours: [hour])], sun: [], fetchedAt: SettingsFixtures.morning)
        let uv = VerdictEngine.outlook(for: input)[0].breaches.filter { $0.factor == .uv }
        #expect(uv.map(\.severity) == [.soft])
    }

    // Scenario: rider-profiles: Overlapping window
    @Test("Overlapping window")
    func overlappingWindow() {
        let windows = [
            RideWindow(weekdays: [2], from: (7, 0), to: (9, 0)), RideWindow(weekdays: [2], from: (8, 0), to: (10, 0)),
        ]
        #expect(
            WindowValidator.problems(in: windows).map(\.message) == [
                "These ride windows overlap. Pick times that don't."
            ])
        #expect(WindowValidator.problems(in: RidingStyle.commute.windows).isEmpty)
    }

    @Test func windowsMustEndAfterStartAndStayUnderFourPerDay() {
        #expect(!WindowValidator.problems(in: [RideWindow(weekdays: [2], from: (9, 0), to: (8, 0))]).isEmpty)
        let five = (0..<5).map { RideWindow(weekdays: [3], start: $0 * 120, end: $0 * 120 + 60) }
        #expect(WindowValidator.problems(in: five).map(\.message) == ["A day can have at most 4 ride windows."])
    }

    // Scenario: rider-profiles: Override to metric
    @Test("Override to metric")
    func overrideToMetric() {
        var preferences = SettingsFixtures.preferences()
        let gust = preferences.activeProfile.limits.gusts.soft!
        #expect(UnitPreference.automatic.resolved(locale: Locale(identifier: "en_US")) == .imperial)
        #expect(Quantity.speed.display(gust, in: .imperial).rounded() == 30)
        preferences.unitPreference = .metric
        #expect(Quantity.speed.display(gust, in: preferences.unitPreference.resolved()).rounded() == 48)
        #expect(preferences.activeProfile.limits.gusts.soft == gust)
    }

    @Test(arguments: [Quantity.temperature, .speed, .distance, .precipitationRate, .percentage, .index])
    func conversionsRoundTrip(quantity: Quantity) {
        for units in [UnitSystem.imperial, .metric] {
            let si = 12.34
            #expect(abs(quantity.si(fromDisplay: quantity.display(si, in: units), in: units) - si) < 1e-9)
        }
    }

    @Test func automaticUnitsFollowTheRegion() {
        #expect(UnitPreference.automatic.resolved(locale: Locale(identifier: "en_GB")) == .metric)
        #expect(UnitPreference.automatic.resolved(locale: Locale(identifier: "de_DE")) == .metric)
    }
}
