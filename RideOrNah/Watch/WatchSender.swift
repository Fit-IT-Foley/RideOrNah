import Foundation
import Presentation
import WatchConnectivity

/// The parts of WatchConnectivity the iPhone uses, so tests can use a fake.
protocol WatchSessioning: AnyObject {
    /// A paired watch has the app installed.
    var canSend: Bool { get }
    func send(_ context: [String: Any]) throws
}

/// Sends the newest results; a newer application context replaces an older one on the watch.
final class LiveWatchSession: NSObject, WatchSessioning, WCSessionDelegate {
    private let session: WCSession? = WCSession.isSupported() ? .default : nil

    override init() {
        super.init()
        session?.delegate = self
        session?.activate()
    }

    var canSend: Bool {
        guard let session else { return false }
        return session.activationState == .activated && session.isPaired && session.isWatchAppInstalled
    }

    func send(_ context: [String: Any]) throws { try session?.updateApplicationContext(context) }

    nonisolated func session(
        _ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: (any Error)?
    ) {}
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) { session.activate() }
}

/// Sends the watch what the iPhone just evaluated: verdicts and reasons, never forecasts.
final class WatchSender {
    static let key = WatchStore.contextKey

    let session: any WatchSessioning
    private(set) var lastSent: WatchResults?

    init(session: any WatchSessioning) { self.session = session }

    func send(_ results: WatchResults) {
        guard session.canSend, results != lastSent, let data = try? JSONEncoder().encode(results) else { return }
        do {
            try session.send([Self.key: data])
            lastSent = results
        } catch {
            // The watch keeps its older results, which it labels by age.
        }
    }
}
