import Foundation
import Observation
import Presentation
import RiderSettings
import UserNotifications
import VerdictEngine

/// Keeps the next three ride notifications scheduled with the newest forecast for the background
/// location source, and asks iOS for a refresh before the next one.
@Observable
final class NotificationCoordinator {
    let app: AppModel
    let forecast: ForecastController
    let center: any NotificationCentering
    private(set) var authorization = NotificationAuthorization.notDetermined
    /// What the next notification will say, for the Alerts tab's preview.
    private(set) var next: PlannedNotification?
    /// When access ends because the subscription won't renew; nothing is scheduled past it.
    var accessEnds: () -> Date? = { nil }
    /// Gets the same evaluation, for the watch.
    var watch: WatchSender?

    init(app: AppModel, forecast: ForecastController, center: any NotificationCentering) {
        self.app = app
        self.forecast = forecast
        self.center = center
    }

    static func live(app: AppModel, forecast: ForecastController) -> NotificationCoordinator {
        var center: any NotificationCentering = LiveNotificationCenter()
        #if DEBUG
            if let stub = UserDefaults.standard.string(forKey: "notificationStub") {
                center = StubNotificationCenter(status: stub == "denied" ? .denied : .notDetermined)
            }
        #endif
        return NotificationCoordinator(app: app, forecast: forecast, center: center)
    }

    func refreshAuthorization() async {
        authorization = await center.authorization()
    }

    /// Asks for permission (once) and turns the notification on at the chosen time.
    func enable(at minutesAfterMidnight: Int) async -> Bool {
        let granted = await center.requestAuthorization()
        authorization = await center.authorization()
        guard granted else { return false }
        app.update {
            $0.notifications.isEnabled = true
            $0.notifications.minutesAfterMidnight = minutesAfterMidnight
            $0.sharedModifiedAt = Date()
        }
        await rebuild()
        return true
    }

    /// Rebuilds every pending notification from the newest forecast for the background place.
    func rebuild() async {
        guard let preferences = app.preferences, !forecast.isLocked else {
            // Without access, nothing stays scheduled; settings are kept for when it returns.
            next = nil
            await NotificationScheduler.replace(with: [], in: center)
            if forecast.isLocked { watch?.send(.locked(at: forecast.clock())) }
            return
        }
        let evaluation = await forecast.backgroundEvaluation()
        if let evaluation, let outlook = evaluation.outlook, let fetchedAt = evaluation.fetchedAt {
            var results = WatchResults.make(
                outlook: outlook, fetchedAt: fetchedAt, hasAccess: true, profile: preferences.activeProfile,
                placeName: evaluation.place.name,
                radius: preferences.radius(on: forecast.clock(), calendar: forecast.calendar),
                formatter: forecast.formatter)
            results.attributionMarkURL = forecast.attribution.darkMarkURL
            results.attributionLegalURL = forecast.attribution.legalPageURL
            watch?.send(results)
        }
        let ends = accessEnds()
        let plan = NotificationPlanner(formatter: forecast.formatter).plan(
            settings: preferences.notifications, profile: preferences.activeProfile, outlook: evaluation?.outlook,
            fetchedAt: evaluation?.fetchedAt, now: forecast.clock(), suggestions: preferences.rideSuggestions
        ).filter { item in ends.map { item.fireDate < $0 } ?? true }
        next = plan.first
        await NotificationScheduler.replace(with: plan, in: center)
        if let first = plan.first { BackgroundRefresh.schedule(beforeNotificationAt: first.fireDate) }
    }

    /// The background refresh: fetch with the background purpose, then rebuild.
    func backgroundRefresh() async {
        await forecast.refresh(.background)
        await rebuild()
    }
}

/// Opens Today when the rider taps a ride notification, with the event editor for Add to
/// Calendar, and shows notifications while the app is open.
final class NotificationRouter: NSObject, UNUserNotificationCenterDelegate {
    let app: AppModel
    /// Opens the event editor for a range.
    var addToCalendar: (DateInterval) -> Void = { _ in }

    init(app: AppModel) { self.app = app }

    func openToday() {
        app.selectedTab = .today
    }

    func handle(action: String, userInfo: [AnyHashable: Any]) {
        openToday()
        if action == CalendarAction.identifier, let range = CalendarAction.range(from: userInfo) {
            addToCalendar(range)
        }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse
    ) async {
        let action = response.actionIdentifier
        let userInfo = response.notification.request.content.userInfo
        let start = userInfo["start"] as? TimeInterval
        let end = userInfo["end"] as? TimeInterval
        await MainActor.run {
            var info: [AnyHashable: Any] = [:]
            if let start, let end { info = ["start": start, "end": end] }
            handle(action: action, userInfo: info)
        }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter, willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
