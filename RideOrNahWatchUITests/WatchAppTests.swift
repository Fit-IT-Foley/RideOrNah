import XCTest

/// The watch app on a watch simulator. `-watchSample` stands in for the paired iPhone, with
/// results received at 05:50 that call today Nah for rain from 5 PM.
final class WatchAppTests: XCTestCase {
    @MainActor
    private func launch(at now: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-watchSample", "YES", "-fixedNow", now]
        app.launch()
        return app
    }

    // Scenario: watch-app: Showing received results
    // Scenario: watch-app: Main screen attribution
    @MainActor
    func testMainScreenShowsTheReceivedCallAndTheAppleWeatherMark() {
        let app = launch(at: "2026-06-08T06:00")
        let word = app.descendants(matching: .any)["watch.word"]
        XCTAssertTrue(word.waitForExistence(timeout: 15))
        XCTAssertEqual(word.label, "Nah")
        XCTAssertEqual(app.staticTexts["watch.reason"].label, "Rain likely 5–7 PM (80%)")
        XCTAssertEqual(app.descendants(matching: .any).matching(identifier: "watch.window").count, 2)
        let mark = app.descendants(matching: .any)["attribution.mark"]
        for _ in 0..<10 where !mark.isHittable { app.swipeUp() }
        XCTAssertTrue(mark.isHittable)
    }

    // Scenario: watch-app: Phone left at home
    @MainActor
    func testThirteenHourOldResultsAskForTheIPhone() {
        let app = launch(at: "2026-06-08T19:00")
        let reason = app.staticTexts["watch.reason"]
        XCTAssertTrue(reason.waitForExistence(timeout: 15))
        XCTAssertEqual(reason.label, "Open Ride or Nah on your iPhone.")
        XCTAssertFalse(app.descendants(matching: .any)["watch.word"].exists)
    }
}
