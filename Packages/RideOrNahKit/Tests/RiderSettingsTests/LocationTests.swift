import Foundation
import Testing
import WeatherData

@testable import RiderSettings

struct LocationTests {
    // Scenario: ride-locations: Metric presets
    @Test("Metric presets")
    func metricPresets() {
        #expect(RadiusPreset.allCases.map { $0.label(in: .metric) } == ["Local", "16 km", "40 km", "80 km", "160 km"])
        #expect(
            RadiusPreset.allCases.map { $0.label(in: .imperial) } == ["Local", "10 mi", "25 mi", "50 mi", "100 mi"])
        #expect(RadiusPreset.km80.metres == SampleLayout.innerRingThreshold)
    }

    // Scenario: ride-locations: Switching units keeps the radius
    @Test("Switching units keeps the radius")
    func switchingUnitsKeepsTheRadius() {
        var preferences = SettingsFixtures.preferences()
        preferences.unitPreference = .metric
        #expect(preferences.activeProfile.radius.label(in: .metric) == "40 km")
        preferences.unitPreference = .imperial
        #expect(preferences.activeProfile.radius.label(in: preferences.unitPreference.resolved()) == "25 mi")
        #expect(preferences.activeProfile.radius.metres == 40_000)
    }

    // Scenario: ride-locations: Long ride today
    @Test("Long ride today")
    func longRideToday() {
        var preferences = SettingsFixtures.preferences()
        let today = SettingsFixtures.morning
        let tomorrow = SettingsFixtures.calendar.date(byAdding: .day, value: 1, to: today)!
        preferences.setTodayRadius(.km160, now: today, calendar: SettingsFixtures.calendar)
        #expect(
            preferences.radius(on: today.addingTimeInterval(12 * 3600), calendar: SettingsFixtures.calendar) == .km160)
        #expect(preferences.radius(on: tomorrow, calendar: SettingsFixtures.calendar) == .km40)
        #expect(preferences.activeProfile.radius == .km40)
    }

    // Scenario: ride-locations: Midnight reset
    @Test("Midnight reset")
    func midnightReset() {
        var preferences = SettingsFixtures.preferences()
        preferences.setTodayRadius(.km16, now: SettingsFixtures.morning, calendar: SettingsFixtures.calendar)
        let midnight = SettingsFixtures.calendar.date(
            byAdding: .day, value: 1, to: SettingsFixtures.calendar.startOfDay(for: SettingsFixtures.morning))!
        preferences.clearExpiredOverrides(now: midnight.addingTimeInterval(-1), calendar: SettingsFixtures.calendar)
        #expect(preferences.todayRadius != nil)
        preferences.clearExpiredOverrides(now: midnight, calendar: SettingsFixtures.calendar)
        #expect(preferences.todayRadius == nil)
    }

    // Scenario: ride-locations: Adding Home by search
    @Test("Adding Home by search")
    func addingHomeBySearch() throws {
        var preferences = SettingsFixtures.preferences()
        let home = try preferences.addSavedLocation(named: "Home", at: SettingsFixtures.newYork)
        #expect(preferences.savedLocations.map(\.name) == ["Home"])
        #expect(home.location.coordinate == GeoCoordinate(latitude: 40.71, longitude: -74.01))
    }

    // Scenario: ride-locations: Limit reached
    @Test("Limit reached")
    func limitReached() throws {
        var preferences = SettingsFixtures.preferences()
        for index in 0..<10 { try preferences.addSavedLocation(named: "Place \(index)", at: SettingsFixtures.newYork) }
        #expect(!preferences.canAddSavedLocation)
        #expect(throws: LocationError.limitReached) {
            try preferences.addSavedLocation(named: "One more", at: SettingsFixtures.brooklyn)
        }
    }

    // Scenario: ride-locations: Checking work from home
    @Test("Checking work from home")
    func checkingWorkFromHome() throws {
        var preferences = SettingsFixtures.preferences()
        let work = try preferences.addSavedLocation(named: "Work", at: SettingsFixtures.brooklyn)
        preferences.choose(.saved(work.id))
        let here = LocationReading(coordinate: SettingsFixtures.newYork, isApproximate: false)
        #expect(preferences.evaluationPlace(current: here)?.name == "Work")
        #expect(preferences.evaluationLocation == .saved(work.id))
    }

    // Scenario: ride-locations: No location at all
    @Test("No location at all")
    func noLocationAtAll() {
        #expect(SettingsFixtures.preferences().evaluationPlace(current: nil) == nil)
    }

    // Scenario: ride-locations: Approximate location
    @Test("Approximate location")
    func approximateLocation() {
        let reading = LocationReading(
            coordinate: GeoCoordinate(latitude: 34.05223, longitude: -118.24368), isApproximate: true)
        let place = SettingsFixtures.preferences().evaluationPlace(current: reading)
        #expect(place?.coordinate == GeoCoordinate(latitude: 34.05, longitude: -118.24))
    }

    // Scenario: ride-locations: Default with Home saved
    @Test("Default with Home saved")
    func defaultWithHomeSaved() throws {
        var preferences = SettingsFixtures.preferences()
        try preferences.addSavedLocation(named: "Work", at: SettingsFixtures.brooklyn)
        let home = try preferences.addSavedLocation(named: "home", at: SettingsFixtures.newYork)
        #expect(preferences.effectiveBackgroundSource == .saved(home.id))
        #expect(preferences.backgroundPlace(lastSeen: SettingsFixtures.brooklyn)?.name == "home")
    }

    // Scenario: ride-locations: Last-seen location
    @Test("Last-seen location")
    func lastSeenLocation() {
        var preferences = SettingsFixtures.preferences()
        preferences.backgroundSource = .lastSeen
        let place = preferences.backgroundPlace(lastSeen: SettingsFixtures.brooklyn)
        #expect(place?.coordinate == GeoCoordinate(latitude: 40.68, longitude: -73.94))
    }

    // Scenario: ride-locations: No source available
    @Test("No source available")
    func noSourceAvailable() {
        var preferences = SettingsFixtures.preferences()
        preferences.backgroundSource = .lastSeen
        #expect(preferences.backgroundPlace(lastSeen: nil) == nil)
    }

    @Test func deletingTheBackgroundPlaceFallsBackToTheDefault() throws {
        var preferences = SettingsFixtures.preferences()
        let work = try preferences.addSavedLocation(named: "Work", at: SettingsFixtures.brooklyn)
        preferences.backgroundSource = .saved(work.id)
        preferences.choose(.saved(work.id))
        preferences.deleteSavedLocation(work.id)
        #expect(preferences.backgroundSource == nil)
        #expect(preferences.evaluationLocation == .current)
    }
}
