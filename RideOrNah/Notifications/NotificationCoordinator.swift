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
        guard let preferences = app.preferences else { return }
        let evaluation = await forecast.backgroundEvaluation()
        let plan = NotificationPlanner(formatter: forecast.formatter).plan(
            settings: preferences.notifications, profile: preferences.activeProfile, outlook: evaluation?.outlook,
            fetchedAt: evaluation?.fetchedAt, now: forecast.clock())
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

/// Opens Today when the rider taps a ride notification, and shows it while the app is open.
final class NotificationRouter: NSObject, UNUserNotificationCenterDelegate {
    let app: AppModel

    init(app: AppModel) { self.app = app }

    func openToday() {
        app.selectedTab = .today
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse
    ) async {
        await MainActor.run { openToday() }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter, willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
