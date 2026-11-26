import XCTest

/// Widget taps arrive as `rideornah://` links; these open them the same way.
final class WidgetLinkTests: XCTestCase {
    @MainActor
    private func launch() throws -> XCUIApplication {
        #if !DEBUG
            throw XCTSkip("Uses debug-only fixture weather")
        #else
            let app = XCUIApplication()
            app.launchArguments += [
                "-accessStub", "active", "-skipFirstRun", "YES", "-resetPreferences", "YES", "-locationStub",
                "granted", "-weatherSource", "fixture", "-weatherScenario", "clearDay", "-fixedNow",
                "2026-06-08T06:00",
            ]
            app.launch()
            XCTAssertTrue(app.descendants(matching: .any)["today.word"].waitForExistence(timeout: 15))
            return app
        #endif
    }

    // Scenario: widgets: Tapping Thursday
    @MainActor
    func testTappingThursdayOpensItsDetail() throws {
        let app = try launch()
        app.open(URL(string: "rideornah://day/2026-06-11")!)
        XCTAssertTrue(app.descendants(matching: .any)["detail.word"].waitForExistence(timeout: 10))
        let title = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'Thursday 11 Jun'")).firstMatch
        XCTAssertTrue(title.exists)
    }

    // Widgets don't carry the Apple Weather mark; the screen they open does.
    // Scenario: widgets: Attribution through the app
    @MainActor
    func testWidgetTapOpensTodayWithAttribution() throws {
        let app = try launch()
        app.tabBars.buttons["Week"].tap()
        app.open(URL(string: "rideornah://today")!)
        XCTAssertTrue(app.descendants(matching: .any)["today.screen"].waitForExistence(timeout: 10))
        let link = app.descendants(matching: .any)["attribution.link"]
        for _ in 0..<8 where !link.exists { app.swipeUp() }
        XCTAssertTrue(link.exists)
        XCTAssertTrue(app.descendants(matching: .any)["attribution.mark"].exists)
    }
}
