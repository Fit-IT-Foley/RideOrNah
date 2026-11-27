import XCTest

/// The paywall and the locked screens, with a stand-in store (debug builds only), so no
/// StoreKit sheet or sandbox account is involved.
final class PaywallTests: XCTestCase {
    @MainActor
    private func launch(_ arguments: [String]) throws -> XCUIApplication {
        #if !DEBUG
            throw XCTSkip("Uses debug-only launch arguments")
        #else
            let app = XCUIApplication()
            app.launchArguments +=
                [
                    "-accessStub", "inactive", "-locationStub", "granted", "-weatherSource", "fixture",
                    "-weatherScenario", "clearDay", "-fixedNow", "2026-06-08T06:00",
                ] + arguments
            app.launch()
            return app
        #endif
    }

    // Scenario: subscription: After setup
    // Scenario: subscription: Required disclosures
    // Scenario: app-release: Local prices
    @MainActor
    func testPaywallFollowsSetup() throws {
        let app = try launch(["-resetPreferences", "YES"])
        XCTAssertTrue(app.descendants(matching: .any)["firstRun.screen"].waitForExistence(timeout: 10))
        app.buttons["firstRun.style.commute"].tap()
        app.buttons["firstRun.limits.confirm"].tap()
        app.buttons["firstRun.location.allow"].tap()
        let skip = app.buttons["firstRun.notifications.skip"]
        XCTAssertTrue(skip.waitForExistence(timeout: 15))
        skip.tap()

        XCTAssertTrue(app.descendants(matching: .any)["paywall.screen"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.descendants(matching: .any)["today.word"].exists)
        XCTAssertEqual(app.buttons["paywall.subscribe"].label, "Start free trial")
        let disclosure = app.staticTexts["paywall.disclosure"]
        // iOS 26 and 27 expose SwiftUI links as different element types, so match any type.
        let terms = app.descendants(matching: .any)["paywall.terms"]
        let privacy = app.descendants(matching: .any)["paywall.privacy"]
        for _ in 0..<4 where !privacy.exists { app.swipeUp() }
        XCTAssertTrue(disclosure.label.hasPrefix("Free for 1 week, then $19.99 a year. Renews automatically"))
        XCTAssertTrue(app.buttons["paywall.plan.monthly"].label.contains("$2.99 a month"))
        XCTAssertTrue(app.buttons["paywall.restore"].exists)
        XCTAssertTrue(terms.exists)
        XCTAssertTrue(privacy.exists)
    }

    // Scenario: subscription: Dismissed paywall
    @MainActor
    func testClosingThePaywallLeavesALockedToday() throws {
        let app = try launch(["-skipFirstRun", "YES"])
        let locked = app.buttons["locked.seePlans"]
        XCTAssertTrue(locked.waitForExistence(timeout: 10))
        XCTAssertFalse(app.descendants(matching: .any)["today.word"].exists)

        app.buttons["locked.seePlans"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["paywall.screen"].waitForExistence(timeout: 15))
        app.buttons["paywall.close"].tap()
        XCTAssertTrue(locked.waitForExistence(timeout: 15))

        // Settings stay usable without access.
        app.buttons["root.settings"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["settings.screen"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["settings.profile"].firstMatch.exists)
        app.buttons["Done"].tap()

        // Subscribing unlocks Today without a relaunch.
        app.buttons["locked.seePlans"].tap()
        let subscribe = app.buttons["paywall.subscribe"]
        XCTAssertTrue(subscribe.waitForExistence(timeout: 15))
        subscribe.tap()
        XCTAssertTrue(app.descendants(matching: .any)["today.word"].waitForExistence(timeout: 15))
    }
}
