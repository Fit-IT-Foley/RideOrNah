import SwiftUI
import UserNotifications

@main
struct RideOrNahApp: App {
    @State private var model: AppModel
    @State private var forecast: ForecastController
    @State private var notifications: NotificationCoordinator
    @State private var access: AccessController
    private let router: NotificationRouter

    init() {
        let model = AppModel.live()
        let forecast = ForecastController.live(app: model)
        let notifications = NotificationCoordinator.live(app: model, forecast: forecast)
        let access = AccessController.live()
        access.connect(forecast: forecast, notifications: notifications)
        Task { await access.start() }
        router = NotificationRouter(app: model)
        UNUserNotificationCenter.current().delegate = router
        _model = State(initialValue: model)
        _forecast = State(initialValue: forecast)
        _notifications = State(initialValue: notifications)
        _access = State(initialValue: access)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .environment(forecast)
                .environment(notifications)
                .environment(access)
                .preferredColorScheme(.dark)
        }
        .backgroundTask(.appRefresh(BackgroundRefresh.identifier)) {
            // Access first, so a lapsed subscription stops notifications before the morning.
            await access.refresh()
            await notifications.backgroundRefresh()
        }
    }
}
