import XCTest

final class AccessibilityTests: XCTestCase {
    // A text element can't report glyph truncation, so the attached screenshot is kept for that.
    // Scenario: app-platform: Largest text size
    @MainActor
    func testLargestAccessibilityTextSizeKeepsTextOnScreen() {
        let app = XCUIApplication()
        app.launchArguments += [
            "-skipFirstRun", "YES", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL",
        ]
        app.launch()

        let window = app.windows.firstMatch
        for identifier in ["root.title", "root.subtitle"] {
            let text = app.staticTexts[identifier]
            XCTAssertTrue(text.waitForExistence(timeout: 10), "\(identifier) is missing")
            XCTAssertTrue(window.frame.contains(text.frame), "\(identifier) runs off screen")
        }

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Largest text size"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    // Hosted CI simulators ignore device appearance changes, so CI sets CI=true and skips this;
    // RideOrNahTests' AppearanceTests covers the scenario there.
    // Scenario: app-platform: Switching appearance
    @MainActor
    func testSwitchingAppearanceKeepsTheDarkLook() throws {
        try XCTSkipIf(
            ProcessInfo.processInfo.environment["CI"] == "true",
            "CI simulators ignore device appearance changes; AppearanceTests covers this scenario")
        XCUIDevice.shared.appearance = .light
        defer { XCUIDevice.shared.appearance = .light }

        let app = XCUIApplication()
        app.launchArguments += ["-skipFirstRun", "YES"]
        app.launch()
        XCTAssertTrue(app.staticTexts["root.title"].waitForExistence(timeout: 10))
        let withLightSystem = try backgroundBrightness(of: app)

        XCUIDevice.shared.appearance = .dark
        RunLoop.current.run(until: .now.addingTimeInterval(2))
        let withDarkSystem = try backgroundBrightness(of: app)

        XCTAssertEqual(app.state, .runningForeground, "the app relaunched or left the foreground")
        XCTAssertLessThan(withLightSystem, 0.3, "the light system setting made the app light")
        XCTAssertLessThan(withDarkSystem, 0.3, "the app wasn't dark after switching")
    }

    /// Relative luminance (0–1) of one pixel of screen background, below the placeholder card.
    @MainActor
    private func backgroundBrightness(of app: XCUIApplication) throws -> Double {
        let image = try XCTUnwrap(app.screenshot().image.cgImage)
        let pixel = try XCTUnwrap(
            image.cropping(to: CGRect(x: image.width / 2, y: image.height * 9 / 10, width: 1, height: 1)))
        var rgba = [UInt8](repeating: 0, count: 4)
        rgba.withUnsafeMutableBytes { buffer in
            let context = CGContext(
                data: buffer.baseAddress, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            context?.draw(pixel, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        }
        return (0.2126 * Double(rgba[0]) + 0.7152 * Double(rgba[1]) + 0.0722 * Double(rgba[2])) / 255
    }
}
