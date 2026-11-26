import XCTest

/// Ride suggestions in Week with fixture weather. `-calendarStub` answers for the system editor,
/// except in the test that opens the real one.
final class CalendarTests: XCTestCase {
    @MainActor
    private func launch(calendar stub: String?) throws -> XCUIApplication {
        #if !DEBUG
            throw XCTSkip("Uses debug-only launch arguments")
        #else
            let app = XCUIApplication()
            app.launchArguments += [
                "-accessStub", "active", "-skipFirstRun", "YES", "-resetPreferences", "YES", "-locationStub",
                "granted", "-weatherSource", "fixture", "-weatherScenario", "clearDay", "-fixedNow",
                "2026-06-08T06:00",
            ]
            if let stub { app.launchArguments += ["-calendarStub", stub] }
            app.launch()
            XCTAssertTrue(app.descendants(matching: .any)["today.word"].waitForExistence(timeout: 15))
            // Ride suggestions are off until the rider turns them on in Alerts.
            app.tabBars.buttons["Week"].tap()
            XCTAssertTrue(app.buttons.matching(identifier: "week.row").firstMatch.waitForExistence(timeout: 5))
            XCTAssertFalse(app.buttons["suggestion.add"].exists)
            app.tabBars.buttons["Alerts"].tap()
            let toggle = app.switches["alerts.suggestions"]
            for _ in 0..<4 where !toggle.exists { app.swipeUp() }
            XCTAssertTrue(toggle.waitForExistence(timeout: 5))
            toggle.switches.firstMatch.exists ? toggle.switches.firstMatch.tap() : toggle.tap()
            app.tabBars.buttons["Week"].tap()
            return app
        #endif
    }

    // Scenario: ride-calendar: Saving a ride
    @MainActor
    func testSavingARideMarksItAdded() throws {
        let app = try launch(calendar: "save")
        let add = app.buttons.matching(identifier: "suggestion.add").firstMatch
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        let before = app.buttons.matching(identifier: "suggestion.add").count
        add.tap()
        XCTAssertTrue(app.buttons["suggestion.added"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons.matching(identifier: "suggestion.add").count, before - 1)
        XCTAssertEqual(app.alerts.count, 0)
    }

    // Scenario: ride-calendar: Cancelling
    @MainActor
    func testCancellingKeepsTheSuggestion() throws {
        let app = try launch(calendar: "cancel")
        let add = app.buttons.matching(identifier: "suggestion.add").firstMatch
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        let before = app.buttons.matching(identifier: "suggestion.add").count
        add.tap()
        XCTAssertFalse(app.buttons["suggestion.added"].waitForExistence(timeout: 2))
        XCTAssertEqual(app.buttons.matching(identifier: "suggestion.add").count, before)
    }

    // The real system editor opens without a calendar permission prompt.
    // Scenario: ride-calendar: Saving a ride
    @MainActor
    func testTheSystemEditorOpensWithoutAPermissionPrompt() throws {
        let app = try launch(calendar: nil)
        let add = app.buttons.matching(identifier: "suggestion.add").firstMatch
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        add.tap()
        let cancel = app.buttons["Cancel"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 10))
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        XCTAssertEqual(springboard.alerts.count, 0)
        XCTAssertEqual(app.alerts.count, 0)
        cancel.tap()
        XCTAssertTrue(add.waitForExistence(timeout: 5))
    }
}
