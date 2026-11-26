import Foundation
import Observation
import Presentation
import WidgetKit

/// The last results from the iPhone, kept on the watch for the app and its complications.
@Observable
final class WatchStore {
    /// The application-context key the iPhone sends results under.
    nonisolated static let contextKey = "results"
    nonisolated static let storageKey = "watch.results"

    private(set) var results: WatchResults?
    let defaults: UserDefaults
    var reloadComplications: () -> Void = { WidgetCenter.shared.reloadAllTimelines() }

    init(defaults: UserDefaults) {
        self.defaults = defaults
        results = Self.load(from: defaults)
    }

    nonisolated static func load(from defaults: UserDefaults) -> WatchResults? {
        defaults.data(forKey: storageKey).flatMap { try? JSONDecoder().decode(WatchResults.self, from: $0) }
    }

    /// Stores new results from the iPhone and reloads the complications.
    func receive(_ data: Data?) {
        guard let data, let decoded = try? JSONDecoder().decode(WatchResults.self, from: data) else { return }
        results = decoded
        defaults.set(data, forKey: Self.storageKey)
        reloadComplications()
    }
}
