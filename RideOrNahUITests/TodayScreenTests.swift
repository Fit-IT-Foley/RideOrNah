import XCTest

/// Today, Week and Day detail on fixture weather with a fixed clock (Monday 6 AM, afternoon
/// rain), so the call is the same on every run.
final class TodayScreenTests: XCTestCase {
    @MainActor
    private func launch() throws -> XCUIApplication {
        #if !DEBUG
            throw XCTSkip("Uses debug-only fixture weather")
        #else
            let app = XCUIApplication()
            app.launchArguments += [
                "-accessStub", "active",
                "-skipFirstRun", "YES", "-resetPreferences", "YES", "-locationStub", "granted", "-weatherSource",
                "fixture", "-weatherScenario", "afternoonRain", "-fixedNow", "2026-06-08T06:00",
            ]
            app.launch()
            return app
        #endif
    }

    // VoiceOver reads the verdict as a word; its color is never the only signal.
    // Scenario: app-platform: Color-independent state
    // Scenario: verdict-display: Nah from rain
    @MainActor
    func testTodayShowsTheCallInWords() throws {
        let app = try launch()
        let verdict = app.descendants(matching: .any)["today.word"]
        XCTAssertTrue(verdict.waitForExistence(timeout: 15))
        XCTAssertEqual(verdict.label, "Nah")
        XCTAssertEqual(app.staticTexts["today.summary"].label, "Rain likely 4–6 PM (80%)")
        XCTAssertTrue(app.staticTexts["today.freshness"].label.hasPrefix("Current location · Mon 8 Jun"))
    }

    // Scenario: verdict-display: Outlook confidence marker
    @MainActor
    func testWeekListsSevenDaysWithLowerConfidenceMarked() throws {
        let app = try launch()
        XCTAssertTrue(app.descendants(matching: .any)["today.word"].waitForExistence(timeout: 15))
        app.tabBars.buttons["Week"].tap()
        let rows = app.buttons.matching(identifier: "week.row")
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 5))
        for _ in 0..<4 where rows.count < 7 { app.swipeUp() }
        XCTAssertEqual(rows.count, 7)
        // Each row reads as one element, so the marker is part of the row's label.
        XCTAssertEqual(rows.matching(NSPredicate(format: "label CONTAINS 'Lower confidence'")).count, 4)
    }

    // Scenario: verdict-display: Day detail attribution
    @MainActor
    func testDayDetailShowsAttribution() throws {
        let app = try launch()
        XCTAssertTrue(app.descendants(matching: .any)["today.word"].waitForExistence(timeout: 15))
        app.tabBars.buttons["Week"].tap()
        let firstDay = app.buttons.matching(identifier: "week.row").firstMatch
        XCTAssertTrue(firstDay.waitForExistence(timeout: 5))
        firstDay.tap()
        XCTAssertTrue(app.descendants(matching: .any)["detail.word"].waitForExistence(timeout: 5))
        let mark = app.descendants(matching: .any)["attribution.mark"]
        let link = app.descendants(matching: .any)["attribution.link"]
        for _ in 0..<6 where !link.exists { app.swipeUp() }
        XCTAssertTrue(mark.exists)
        XCTAssertTrue(link.exists)
    }
}
