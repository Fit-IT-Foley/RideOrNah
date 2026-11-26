import Foundation

extension AccessController {
    /// Locks weather and notifications without access, and brings them back when it returns,
    /// with the rider's settings as they were.
    func connect(forecast: ForecastController, notifications: NotificationCoordinator) {
        forecast.setLocked(!lastKnownActive)
        forecast.onRefreshed = { await notifications.rebuild() }
        notifications.accessEnds = { [weak self] in self?.endsAt }
        onChange = { access in
            forecast.setLocked(!access.isActive)
            if access.isActive { await forecast.refresh(.foreground) } else { await notifications.rebuild() }
        }
    }
}
