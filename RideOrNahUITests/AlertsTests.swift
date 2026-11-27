import XCTest

/// The Alerts tab on fixture weather with a fixed clock and a notification center that grants
/// without the system prompt.
final class AlertsTests: XCTestCase {
    // Scenario: ride-notifications: Settings change
    @MainActor
    func testChangingTheNotificationTime() throws {
        #if !DEBUG
            throw XCTSkip("Uses debug-only fixture weather and notification stub")
        #else
            let app = XCUIApplication()
            app.launchArguments += [
                "-accessStub", "active",
                "-skipFirstRun", "YES", "-resetPreferences", "YES", "-locationStub", "granted", "-weatherSource",
                "fixture", "-weatherScenario", "clearDay", "-fixedNow", "2026-06-08T05:00", "-notificationStub",
                "granted",
            ]
            app.launch()
            XCTAssertTrue(app.descendants(matching: .any)["today.word"].waitForExistence(timeout: 15))
            app.tabBars.buttons["Alerts"].tap()
            let toggle = app.switches["alerts.toggle"]
            XCTAssertTrue(toggle.waitForExistence(timeout: 15))
            toggle.switches.firstMatch.exists ? toggle.switches.firstMatch.tap() : toggle.tap()
            let previewTime = app.staticTexts["alerts.previewTime"]
            for _ in 0..<4 where !previewTime.exists { app.swipeUp() }
            XCTAssertTrue(previewTime.waitForExistence(timeout: 15))
            XCTAssertEqual(previewTime.label, "MON 8 JUN, 6:30 AM")

            for _ in 0..<4 { app.swipeDown() }
            let time = app.datePickers["alerts.time"]
            XCTAssertTrue(time.waitForExistence(timeout: 15))
            time.buttons.firstMatch.exists ? time.buttons.firstMatch.tap() : time.tap()
            let wheels = app.pickerWheels
            XCTAssertTrue(wheels.firstMatch.waitForExistence(timeout: 15))
            wheels.element(boundBy: 0).adjust(toPickerWheelValue: "5")
            wheels.element(boundBy: 1).adjust(toPickerWheelValue: "45")
            app.tap(at: CGVector(dx: 0.5, dy: 0.08))

            for _ in 0..<4 where !previewTime.exists { app.swipeUp() }
            let moved = NSPredicate(format: "label == %@", "MON 8 JUN, 5:45 AM")
            expectation(for: moved, evaluatedWith: previewTime)
            waitForExpectations(timeout: 5)
        #endif
    }
}

extension XCUIApplication {
    /// Taps a point given as a fraction of the screen, such as outside a popover.
    func tap(at offset: CGVector) {
        coordinate(withNormalizedOffset: offset).tap()
    }
}
