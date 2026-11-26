import Foundation
import Observation
import Presentation
import RiderSettings
import VerdictEngine

/// Ride suggestions: which stretches to offer, the event editor on screen, and the rides the
/// rider has added, re-checked against each newer forecast. Never reads the calendar.
@Observable
final class RideCalendar {
    let app: AppModel
    let forecast: ForecastController
    /// The event editor on screen, if any.
    var draft: CalendarDraft?
    private(set) var added: [AddedRide]
    #if DEBUG
        /// `-calendarStub save|cancel` answers for the editor in UI tests.
        let stub: String?
    #endif

    init(app: AppModel, forecast: ForecastController) {
        self.app = app
        self.forecast = forecast
        app.store.pruneAddedRides(now: forecast.clock(), calendar: forecast.calendar)
        added = app.store.addedRides
        #if DEBUG
            stub = UserDefaults.standard.string(forKey: "calendarStub")
        #endif
    }

    var isOn: Bool { app.preferences?.rideSuggestions ?? false }

    /// The day's suggestions, or none while they're off, locked, stale or Unknown.
    func suggestions(for day: Date) -> [RideSuggestion] {
        guard !forecast.isLocked,
            let evaluation = forecast.outlook?.first(where: { forecast.calendar.isDate($0.day, inSameDayAs: day) })
        else { return [] }
        return SuggestionPresenter(formatter: forecast.formatter).suggestions(
            for: evaluation, isOn: isOn, added: added, fetchedAt: forecast.snapshot?.fetchedAt, now: forecast.clock())
    }

    /// Opens the event editor for `range`.
    func add(_ range: DateInterval) {
        guard let preferences = app.preferences else { return }
        draft = CalendarDraft(
            range: range, profileName: preferences.activeProfile.name, placeName: forecast.place?.name ?? "",
            radius: preferences.radius(on: range.start, calendar: forecast.calendar),
            fetchedAt: forecast.snapshot?.fetchedAt ?? forecast.clock(), formatter: forecast.formatter)
        #if DEBUG
            if let stub { finish(saved: stub == "save") }
        #endif
    }

    /// Called when the editor closes. Only a saved event is remembered.
    func finish(saved: Bool) {
        defer { draft = nil }
        guard saved, let draft else { return }
        app.store.recordAddedRide(
            AddedRide(
                range: draft.range, profileName: app.preferences?.activeProfile.name ?? "",
                placeName: draft.location))
        added = app.store.addedRides
    }

    /// Added rides still ahead, re-checked with the newest forecast.
    var statuses: [AddedRideStatus] {
        guard !forecast.isLocked, let preferences = app.preferences, let snapshot = forecast.snapshot else { return [] }
        let now = forecast.clock()
        guard
            let input = snapshot.evaluationInput(
                profile: preferences.activeProfile.snapshot, now: now, calendar: forecast.calendar)
        else { return [] }
        let check = AddedRideCheck(formatter: forecast.formatter)
        return added.filter { $0.end > now }.map {
            check.status($0, evaluation: VerdictEngine.evaluate(range: $0.range, in: input))
        }
    }
}
