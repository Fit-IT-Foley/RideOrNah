import XCTest

final class LaunchTests: XCTestCase {
    // `make test` runs this on the oldest supported iOS (26) and the newest.
    // Scenario: app-platform: Install on the oldest supported OS
    @MainActor
    func testLaunchShowsPlaceholderTitle() {
        let app = XCUIApplication()
        app.launchArguments += [
            "-skipFirstRun", "YES", "-locationStub", "granted", "-weatherSource", "fixture", "-weatherScenario",
            "afternoonRain", "-fixedNow", "2026-06-08T06:00",
        ]
        app.launch()

        let verdict = app.descendants(matching: .any)["today.word"]
        XCTAssertTrue(verdict.waitForExistence(timeout: 15))
        XCTAssertEqual(verdict.label, "Nah")

        // Kept even when the test passes, so CI can publish what each simulator showed.
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Launch"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }
}
