import XCTest

/// The debug weather pipeline screen, on fixture data, and the Release build without it.
final class WeatherPipelineTests: XCTestCase {
    @MainActor
    private func launchPipeline(scenario: String) throws -> XCUIApplication {
        #if !DEBUG
            throw XCTSkip("The pipeline screen exists only in debug builds")
        #else
            let app = XCUIApplication()
            app.launchArguments += [
                "-accessStub", "active",
                "-skipFirstRun", "YES", "-openWeatherDebug", "YES", "-weatherSource", "fixture", "-weatherScenario",
                scenario,
            ]
            app.launch()
            return app
        #endif
    }

    // Scenario: weather-data: Debug fixture
    @MainActor
    func testStormFixtureShowsStormsToTheNorthWithoutRequests() throws {
        let app = try launchPipeline(scenario: "stormToTheNorth")
        let requests = app.staticTexts["weatherDebug.requests"]
        XCTAssertTrue(requests.waitForExistence(timeout: 15))
        XCTAssertEqual(requests.label, "Network requests: 0")
        // The breach rows sit below the fold of a lazily loaded form, so scroll until they exist.
        let breaches = app.staticTexts.matching(identifier: "weatherDebug.breach")
        let storm = breaches.matching(NSPredicate(format: "label BEGINSWITH 'storm, hard'")).firstMatch
        for _ in 0..<6 where !storm.exists { app.swipeUp() }
        XCTAssertTrue(storm.exists, "breaches shown: \(breaches.allElementsBoundByIndex.map(\.label))")
        XCTAssertEqual(storm.label, "storm, hard, N NE NW")
    }

    // Scenario: weather-data: Verdict screen
    @MainActor
    func testPipelineScreenShowsWeatherAttribution() throws {
        let app = try launchPipeline(scenario: "clearDay")
        XCTAssertTrue(app.staticTexts["weatherDebug.verdict"].waitForExistence(timeout: 15))
        let mark = app.descendants(matching: .any)["attribution.mark"]
        let link = app.descendants(matching: .any)["attribution.link"]
        XCTAssertTrue(mark.waitForExistence(timeout: 5))
        XCTAssertTrue(link.exists)
    }
}

/// Runs against a Release build with `make test-release`; skipped in Debug.
final class ReleaseBuildTests: XCTestCase {
    // Scenario: weather-data: Release build
    @MainActor
    func testReleaseBuildIgnoresFixtureArguments() throws {
        #if DEBUG
            throw XCTSkip("Checks Release builds; run make test-release")
        #else
            let app = XCUIApplication()
            app.launchArguments += [
                "-accessStub", "active",
                "-openWeatherDebug", "YES", "-weatherSource", "fixture", "-weatherScenario", "stormToTheNorth",
            ]
            app.launch()
            // Release builds have no setup shortcut, so the app opens on setup or the root screen.
            let opened =
                app.descendants(matching: .any)["today.screen"].waitForExistence(timeout: 10)
                || app.descendants(matching: .any)["firstRun.screen"].exists
            XCTAssertTrue(opened)
            XCTAssertFalse(app.descendants(matching: .any)["weatherDebug.screen"].exists)
            XCTAssertFalse(app.buttons["settings.weatherDebug"].exists)
            XCTAssertFalse(app.staticTexts["weatherDebug.requests"].exists)
        #endif
    }
}
