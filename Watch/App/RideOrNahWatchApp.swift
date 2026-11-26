import Foundation
import Presentation
import SwiftUI
import WatchConnectivity

@main
struct RideOrNahWatchApp: App {
    @State private var store: WatchStore
    private let receiver: WatchReceiver

    init() {
        let group = Bundle.main.object(forInfoDictionaryKey: "RideOrNahAppGroup") as? String
        let store = WatchStore(defaults: group.flatMap(UserDefaults.init(suiteName:)) ?? .standard)
        receiver = WatchReceiver(store: store)
        _store = State(initialValue: store)
    }

    var body: some Scene {
        WindowGroup {
            WatchRootView().environment(store)
        }
    }
}

/// Follows the clock, so ended windows and midnight change the screen without new results.
struct WatchRootView: View {
    @Environment(WatchStore.self) private var store

    var body: some View {
        TimelineView(.everyMinute) { context in
            WatchMainView(
                content: WatchPresenter(formatter: DisplayFormatter(units: .imperial, calendar: .current))
                    .content(store.results, now: context.date),
                markURL: store.results?.attributionMarkURL, legalURL: store.results?.attributionLegalURL)
        }
    }
}

/// Receives the iPhone's results.
final class WatchReceiver: NSObject, WCSessionDelegate {
    let store: WatchStore

    init(store: WatchStore) {
        self.store = store
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    nonisolated func session(
        _ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: (any Error)?
    ) {
        let data = session.receivedApplicationContext[WatchStore.contextKey] as? Data
        Task { @MainActor in store.receive(data) }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        let data = applicationContext[WatchStore.contextKey] as? Data
        Task { @MainActor in store.receive(data) }
    }
}
