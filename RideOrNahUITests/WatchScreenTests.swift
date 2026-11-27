import XCTest

/// The watch app's screen, shown on the iPhone with `-watchPreview` from this iPhone's own
/// results. `WatchAppTests` checks the same screen on a watch simulator.
final class WatchScreenTests: XCTestCase {
    // Scenario: watch-app: Main screen attribution
    @MainActor
    func testWatchScreenShowsTheVerdictAndTheAppleWeatherMark() throws {
        #if !DEBUG
            throw XCTSkip("Uses debug-only launch arguments")
        #else
            let app = XCUIApplication()
            app.launchArguments += [
                "-accessStub", "active", "-skipFirstRun", "YES", "-resetPreferences", "YES", "-locationStub",
                "granted", "-weatherSource", "fixture", "-weatherScenario", "afternoonRain", "-fixedNow",
                "2026-06-08T06:00", "-watchPreview", "YES",
            ]
            app.launch()
            let word = app.descendants(matching: .any)["watch.word"]
            XCTAssertTrue(word.waitForExistence(timeout: 15))
            XCTAssertEqual(word.label, "Nah")
            XCTAssertEqual(app.descendants(matching: .any).matching(identifier: "watch.window").count, 2)
            let mark = app.descendants(matching: .any)["attribution.mark"]
            for _ in 0..<6 where !mark.isHittable { app.swipeUp() }
            XCTAssertTrue(mark.exists)
        #endif
    }
}
