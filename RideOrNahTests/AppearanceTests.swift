import CoreGraphics
import SwiftUI
import Testing
import WeatherData

@testable import RideOrNah

/// The app always uses its dark look. Rendering Today in each system color scheme shows the screen
/// ignores the setting. Hosted CI simulators can't switch the device appearance, so this is the
/// check that runs everywhere; the live switch is `AccessibilityTests.testSwitchingAppearanceKeepsTheDarkLook`.
@MainActor
struct AppearanceTests {
    // Scenario: app-platform: Light system setting
    // Scenario: app-platform: Switching appearance
    @Test("Light system setting")
    func rootViewStaysDarkInEitherSystemScheme() throws {
        let model = AppModel.preview()
        let forecast = ForecastController(
            app: model, source: .fixture(.clearDay), clock: { Date() },
            cache: ForecastCache(directory: FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)),
            budget: nil)
        let light = try backgroundBrightness(
            of: TodayView(tab: .constant(.today)).environment(model).environment(forecast)
                .environment(RideCalendar(app: model, forecast: forecast)), in: .light)
        let dark = try backgroundBrightness(
            of: TodayView(tab: .constant(.today)).environment(model).environment(forecast)
                .environment(RideCalendar(app: model, forecast: forecast)), in: .dark)

        #expect(light < 0.3, "the light system setting changed the background")
        #expect(dark < 0.3, "the dark background wasn't dark")
    }

    /// Relative luminance (0–1) of one pixel of background, below the placeholder card.
    private func backgroundBrightness(of view: some View, in scheme: ColorScheme) throws -> Double {
        let renderer = ImageRenderer(
            content: view.environment(\.colorScheme, scheme).frame(width: 390, height: 844))
        renderer.scale = 1
        let image = try #require(renderer.cgImage)
        let pixel = try #require(
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
