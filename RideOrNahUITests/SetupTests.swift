import XCTest

/// First-run setup and settings, with stubbed location and place search (debug builds only).
final class SetupTests: XCTestCase {
    @MainActor
    private func launch(_ arguments: [String], access: String = "active") throws -> XCUIApplication {
        #if !DEBUG
            throw XCTSkip("Uses debug-only launch arguments")
        #else
            let app = XCUIApplication()
            app.launchArguments += ["-accessStub", access] + arguments
            app.launch()
            return app
        #endif
    }

    /// Swipes up until `element` exists, for rows in lazily loaded lists.
    @MainActor
    private func reveal(_ element: XCUIElement, in app: XCUIApplication) -> Bool {
        for _ in 0..<8 where !element.exists { app.swipeUp() }
        return element.exists
    }

    // Scenario: rider-profiles: Quick setup
    @MainActor
    func testQuickSetupLandsOnMyBike() throws {
        let app = try launch(["-resetPreferences", "YES", "-locationStub", "granted"])
        XCTAssertTrue(app.descendants(matching: .any)["firstRun.screen"].waitForExistence(timeout: 10))
        app.buttons["firstRun.style.commute"].tap()
        app.buttons["firstRun.limits.confirm"].tap()
        app.buttons["firstRun.location.allow"].tap()
        let skip = app.buttons["firstRun.notifications.skip"]
        XCTAssertTrue(skip.waitForExistence(timeout: 15))
        skip.tap()
        let profile = app.buttons["today.profileChip"]
        XCTAssertTrue(profile.waitForExistence(timeout: 10))
        XCTAssertEqual(profile.label, "Profile: My Bike. Change profile")
    }

    // Scenario: rider-profiles: Soft beyond hard
    @MainActor
    func testInvalidLimitShowsWhyAndBlocksSaving() throws {
        let app = try launch(["-skipFirstRun", "YES"])
        app.buttons["root.settings"].tap()
        app.buttons["settings.profile"].firstMatch.tap()
        let gustSoft = app.textFields["limit.Gusts.soft"]
        XCTAssertTrue(reveal(gustSoft, in: app))
        gustSoft.tap()
        gustSoft.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 8) + "99")
        app.navigationBars.firstMatch.tap()
        app.swipeDown()
        let problem = app.staticTexts.matching(identifier: "profile.problem").firstMatch
        for _ in 0..<8 where !problem.exists { app.swipeDown() }
        XCTAssertTrue(problem.exists)
        XCTAssertEqual(problem.label, "The soft limit must be lower than the hard limit.")
        XCTAssertFalse(app.buttons["profile.save"].isEnabled)
    }

    // Scenario: ride-locations: Adding Home by search
    @MainActor
    func testAddingAPlaceBySearch() throws {
        let app = try launch(["-skipFirstRun", "YES", "-resetPreferences", "YES", "-searchStub", "YES"])
        app.buttons["root.settings"].tap()
        let places = app.buttons["settings.places"]
        XCTAssertTrue(reveal(places, in: app))
        places.tap()
        app.buttons["places.add"].tap()
        let search = app.textFields["places.search"]
        XCTAssertTrue(search.waitForExistence(timeout: 15))
        search.tap()
        search.typeText("Main\n")
        let result = app.buttons["places.result"].firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 15))
        result.tap()
        let saved = app.staticTexts["places.saved"].firstMatch
        XCTAssertTrue(saved.waitForExistence(timeout: 15))
        XCTAssertEqual(saved.label, "Main Street")
    }
}
