import Foundation
import Presentation
import SwiftUI
import Testing
import WidgetKit

@testable import RideOrNah

/// Records what would go to the watch.
final class FakeWatchSession: WatchSessioning {
    var canSend = true
    private(set) var sent: [[String: Any]] = []
    func send(_ context: [String: Any]) throws { sent.append(context) }

    var lastResults: WatchResults? {
        (sent.last?[WatchStore.contextKey] as? Data).flatMap { try? JSONDecoder().decode(WatchResults.self, from: $0) }
    }
}

@MainActor
struct WatchSenderTests {
    // Scenario: watch-app: Sending after a background refresh
    @Test("Sending after a background refresh")
    func sendingAfterABackgroundRefresh() async {
        let clock = MovableClock(NotificationCoordinatorTests.june(7, 21))
        let (coordinator, _, _) = NotificationCoordinatorTests.coordinator(clock: clock)
        let session = FakeWatchSession()
        coordinator.watch = WatchSender(session: session)
        await coordinator.forecast.refresh(.foreground)
        await coordinator.rebuild()
        #expect(session.lastResults?.fetchedAt == NotificationCoordinatorTests.june(7, 21))
        clock.set(NotificationCoordinatorTests.june(8, 5, 20))
        await coordinator.backgroundRefresh()
        #expect(session.lastResults?.fetchedAt == NotificationCoordinatorTests.june(8, 5, 20))
        #expect(session.lastResults?.hasAccess == true)
        #expect(session.lastResults?.days.first?.verdict == .ride)
    }

    @Test("Nothing is sent without a watch, and a lapse sends no weather")
    func noWatchAndLocked() async {
        let clock = MovableClock(NotificationCoordinatorTests.june(8, 5))
        let (coordinator, _, _) = NotificationCoordinatorTests.coordinator(clock: clock)
        let session = FakeWatchSession()
        session.canSend = false
        coordinator.watch = WatchSender(session: session)
        await coordinator.forecast.refresh(.foreground)
        await coordinator.rebuild()
        #expect(session.sent.isEmpty)
        session.canSend = true
        coordinator.forecast.setLocked(true)
        await coordinator.rebuild()
        #expect(session.lastResults?.hasAccess == false)
        #expect(session.lastResults?.days.isEmpty == true)
    }
}

@MainActor
struct WatchStoreTests {
    static let now = Date()

    static func results() -> WatchResults {
        let day = Calendar.current.startOfDay(for: now)
        return WatchResults(
            fetchedAt: now, hasAccess: true, profileName: "My Bike", placeName: "Home",
            days: [
                WatchDay(
                    day: day, verdict: .nah, summary: "Rain likely 5–7 PM (80%)",
                    windows: [
                        WatchWindow(
                            start: day.addingTimeInterval(23 * 3600), end: day.addingTimeInterval(23.9 * 3600),
                            verdict: .nah, reason: "Rain likely 5–7 PM (80%)")
                    ], directionText: nil, lowerConfidence: false)
            ])
    }

    // Scenario: watch-app: Receiving results
    @Test("Receiving results")
    func receivingResults() throws {
        let defaults = try #require(UserDefaults(suiteName: "watch-\(UUID().uuidString)"))
        let store = WatchStore(defaults: defaults)
        var reloads = 0
        store.reloadComplications = { reloads += 1 }
        #expect(store.results == nil)
        store.receive(try JSONEncoder().encode(Self.results()))
        #expect(store.results == Self.results())
        #expect(reloads == 1)
        #expect(WatchStore(defaults: defaults).results == Self.results())
        let content = WatchPresenter(formatter: DisplayFormatter(units: .imperial, calendar: .current))
            .content(store.results, now: Self.now)
        #expect(content.word == "NAH")
        store.receive(Data("not results".utf8))
        #expect(store.results == Self.results())
        #expect(reloads == 1)
    }

    static func png(_ view: some View, redacted: Bool) -> Data? {
        let renderer = ImageRenderer(
            content: view.environment(\.redactionReasons, redacted ? .privacy : []).frame(width: 180, height: 60))
        renderer.scale = 2
        return renderer.uiImage?.pngData()
    }

    // Scenario: watch-app: Wrist down
    @Test("Wrist down")
    func wristDown() throws {
        var content = WatchPresenter(formatter: DisplayFormatter(units: .imperial, calendar: .current))
            .content(Self.results(), now: Self.now)
        #expect(content.placeName == "Home")
        let withPlace = WatchComplicationView(content: content, family: .accessoryRectangular)
        #expect(try #require(Self.png(withPlace, redacted: false)) != Self.png(withPlace, redacted: true))
        content.placeName = nil
        let withoutPlace = WatchComplicationView(content: content, family: .accessoryRectangular)
        #expect(Self.png(withoutPlace, redacted: false) == Self.png(withoutPlace, redacted: true))
    }
}
