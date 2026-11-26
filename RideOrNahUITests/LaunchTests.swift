import XCTest

final class LaunchTests: XCTestCase {
    // `make test` runs this on the oldest supported iOS (26) and the newest.
    // Scenario: app-platform: Install on the oldest supported OS
    @MainActor
    func testLaunchShowsPlaceholderTitle() {
        let app = XCUIApplication()
        app.launch()

        let title = app.staticTexts["root.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        XCTAssertEqual(title.label, "RideOrNah")

        // Kept even when the test passes, so CI can publish what each simulator showed.
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Launch"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }
}
