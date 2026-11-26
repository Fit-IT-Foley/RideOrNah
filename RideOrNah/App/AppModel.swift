import Foundation
import Observation
import RiderSettings
import SharedContainer

/// The rider's preferences for the running app: loads them (or starts first-run setup), saves
/// every change, and merges edits from the rider's other devices.
@Observable
final class AppModel {
    private(set) var preferences: Preferences?
    private(set) var firstRun: FirstRunFlow?
    /// The tab on screen; a notification tap switches to Today.
    var selectedTab = AppTab.today
    let store: PreferencesStore
    let location: any LocationProviding
    let placeSearch: any PlaceSearching

    init(store: PreferencesStore, location: any LocationProviding, placeSearch: any PlaceSearching) {
        self.store = store
        self.location = location
        self.placeSearch = placeSearch
    }

    /// The app's real dependencies, or debug stand-ins chosen by launch arguments.
    static func live() -> AppModel {
        let group = Bundle.main.object(forInfoDictionaryKey: SharedContainer.infoPlistKey) as? String
        let defaults = group.flatMap(UserDefaults.init(suiteName:)) ?? .standard
        var location: any LocationProviding = LocationService()
        var search: any PlaceSearching = MapPlaceSearch()
        #if DEBUG
            let arguments = UserDefaults.standard
            if arguments.bool(forKey: "resetPreferences") {
                for key in defaults.dictionaryRepresentation().keys { defaults.removeObject(forKey: key) }
            }
            if let stub = arguments.string(forKey: "locationStub") {
                location = StubLocationService(grants: stub == "granted")
            }
            if arguments.bool(forKey: "searchStub") { search = StubPlaceSearch() }
        #endif
        let model = AppModel(
            store: PreferencesStore(defaults: defaults, cloud: CloudKeyValueStore()), location: location,
            placeSearch: search)
        model.load()
        #if DEBUG
            // UI tests that aren't about setup start with a ready "My Bike" commuter profile.
            if UserDefaults.standard.bool(forKey: "skipFirstRun"), model.needsFirstRun { model.completeQuickSetup() }
        #endif
        return model
    }

    #if DEBUG
        /// Finishes setup with the Commute preset and default limits.
        func completeQuickSetup() {
            if firstRun == nil { firstRun = FirstRunFlow() }
            updateFirstRun {
                $0.choose(.commute)
                $0.confirmLimits()
                $0.locationPermission(granted: true)
                $0.skipNotifications()
            }
        }

        /// A set-up model on throwaway storage, for previews and rendering tests.
        static func preview() -> AppModel {
            let defaults = UserDefaults(suiteName: "rideornah-preview-\(UUID().uuidString)")!
            let model = AppModel(
                store: PreferencesStore(defaults: defaults, cloud: nil), location: StubLocationService(grants: true),
                placeSearch: StubPlaceSearch())
            model.load()
            model.completeQuickSetup()
            return model
        }
    #endif

    var needsFirstRun: Bool { preferences == nil }

    func load() {
        if let saved = store.load() {
            preferences = store.merge(into: saved)
        } else if let fromCloud = store.cloudPreferences() {
            preferences = fromCloud
            store.save(fromCloud)
        } else {
            firstRun = store.firstRunProgress ?? FirstRunFlow()
        }
        startObservingCloud()
    }

    // MARK: First run

    func updateFirstRun(_ change: (inout FirstRunFlow) -> Void) {
        guard var flow = firstRun else { return }
        change(&flow)
        firstRun = flow
        store.firstRunProgress = flow
        if flow.step == .done { finishFirstRun() }
    }

    func finishFirstRun() {
        guard let flow = firstRun else { return }
        let finished = flow.finish()
        preferences = finished
        store.save(finished)
        store.firstRunProgress = nil
        firstRun = nil
    }

    // MARK: Changes

    /// Applies a change and saves it.
    func update(_ change: (inout Preferences) throws -> Void) rethrows {
        guard var current = preferences else { return }
        try change(&current)
        preferences = current
        store.save(current)
    }

    /// Remembers where the rider is, on this device only, for "where I last opened the app".
    func recordCurrentLocation() async {
        guard let reading = await location.currentReading() else { return }
        store.lastSeenLocation = reading.coordinate
    }

    private var cloudObserver: NSObjectProtocol?

    private func startObservingCloud() {
        cloudObserver = NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, let current = self.preferences else { return }
                let merged = self.store.merge(into: current)
                if merged != current {
                    self.preferences = merged
                    self.store.save(merged)
                }
            }
        }
    }
}
