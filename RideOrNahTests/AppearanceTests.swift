import CoreGraphics
import SwiftUI
import Testing

@testable import RideOrNah

/// Renders screens in each color scheme. Hosted simulators on CI ignore device appearance
/// changes, so this is the appearance check that runs everywhere; the live switch is the UI test
/// `AccessibilityTests.testSwitchingToDarkModeWhileOpenRedraws`, which runs on local simulators.
@MainActor
struct AppearanceTests {
    // Scenario: app-platform: Switching appearance
    @Test("Switching appearance")
    func rootViewTakesItsColorsFromTheSystemScheme() throws {
        let light = try backgroundBrightness(of: RootView(), in: .light)
        let dark = try backgroundBrightness(of: RootView(), in: .dark)

        #expect(light > 0.7, "light background wasn't light")
        #expect(dark < 0.3, "dark background wasn't dark")
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
