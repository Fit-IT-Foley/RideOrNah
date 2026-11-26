import SwiftUI
import UserNotifications

@main
struct RideOrNahApp: App {
    @State private var model: AppModel
    @State private var forecast: ForecastController
    @State private var notifications: NotificationCoordinator
    private let router: NotificationRouter

    init() {
        let model = AppModel.live()
        let forecast = ForecastController.live(app: model)
        let notifications = NotificationCoordinator.live(app: model, forecast: forecast)
        forecast.onRefreshed = { await notifications.rebuild() }
        router = NotificationRouter(app: model)
        UNUserNotificationCenter.current().delegate = router
        _model = State(initialValue: model)
        _forecast = State(initialValue: forecast)
        _notifications = State(initialValue: notifications)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .environment(forecast)
                .environment(notifications)
                .preferredColorScheme(.dark)
        }
        .backgroundTask(.appRefresh(BackgroundRefresh.identifier)) {
            await notifications.backgroundRefresh()
        }
    }
}
