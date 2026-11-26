import Foundation
import RiderSettings
import Testing

struct AddedRideTests {
    static func store() -> PreferencesStore {
        PreferencesStore(defaults: UserDefaults(suiteName: "added-\(UUID().uuidString)")!, cloud: nil)
    }

    @Test("Added rides stay on the device, once each, until their day passes")
    func recordAndPrune() {
        let calendar = Calendar(identifier: .gregorian)
        let saturday = calendar.date(from: DateComponents(year: 2026, month: 6, day: 13, hour: 11))!
        let ride = AddedRide(
            range: DateInterval(start: saturday, duration: 6.5 * 3600), profileName: "My Bike", placeName: "Home")
        let store = Self.store()
        store.recordAddedRide(ride)
        store.recordAddedRide(ride)
        #expect(store.addedRides == [ride])
        store.pruneAddedRides(now: saturday.addingTimeInterval(3600), calendar: calendar)
        #expect(store.addedRides == [ride])
        store.pruneAddedRides(now: saturday.addingTimeInterval(24 * 3600), calendar: calendar)
        #expect(store.addedRides.isEmpty)
    }
}
