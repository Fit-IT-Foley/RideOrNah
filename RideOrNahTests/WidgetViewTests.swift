import Foundation
import Presentation
import SwiftUI
import Testing
import UIKit

@testable import RideOrNah

@MainActor
struct WidgetViewTests {
    static func png(_ view: some View, redacted: Bool) -> Data? {
        let renderer = ImageRenderer(
            content: view.environment(\.redactionReasons, redacted ? .privacy : [])
                .frame(width: 170, height: 170).background(Theme.ground))
        renderer.scale = 2
        return renderer.uiImage?.pngData()
    }

    // A locked device renders widgets with privacy redaction: only the place name is hidden.
    // Scenario: widgets: Locked device
    @Test("Locked device")
    func lockedDevice() throws {
        var content = WidgetContent.placeholder(calendar: .current)
        content.place = "Home"
        let withPlace = RideWidgetView(content: content)
        let shown = try #require(Self.png(withPlace, redacted: false))
        let hidden = try #require(Self.png(withPlace, redacted: true))
        #expect(shown != hidden)

        content.place = nil
        let withoutPlace = RideWidgetView(content: content)
        #expect(Self.png(withoutPlace, redacted: false) == Self.png(withoutPlace, redacted: true))
    }
}
