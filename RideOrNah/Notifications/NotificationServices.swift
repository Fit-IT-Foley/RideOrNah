import BackgroundTasks
import Foundation
import Presentation
import UserNotifications

enum NotificationAuthorization {
    case notDetermined, granted, denied
}

/// The parts of the notification center the app uses, so tests can use a fake.
protocol NotificationCentering: AnyObject {
    func authorization() async -> NotificationAuthorization
    /// Shows the system prompt if needed; true when allowed.
    func requestAuthorization() async -> Bool
    func pendingIdentifiers() async -> [String]
    func remove(_ identifiers: [String])
    func add(id: String, body: String, at date: Date, day: Date) async
}

final class LiveNotificationCenter: NotificationCentering {
    let center = UNUserNotificationCenter.current()

    func authorization() async -> NotificationAuthorization {
        switch await center.notificationSettings().authorizationStatus {
        case .notDetermined: .notDetermined
        case .denied: .denied
        default: .granted
        }
    }

    func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
    }

    func pendingIdentifiers() async -> [String] {
        await center.pendingNotificationRequests().map(\.identifier)
    }

    func remove(_ identifiers: [String]) {
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    func add(id: String, body: String, at date: Date, day: Date) async {
        let content = UNMutableNotificationContent()
        content.body = body
        content.sound = .default
        content.userInfo = ["day": day.timeIntervalSince1970]
        let parts = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let request = UNNotificationRequest(
            identifier: id, content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: parts, repeats: false))
        try? await center.add(request)
    }
}

#if DEBUG
    /// For tests and UI tests: records requests and answers the prompt without the system dialog.
    final class StubNotificationCenter: NotificationCentering {
        var status: NotificationAuthorization
        private(set) var pending: [String: (body: String, date: Date)] = [:]

        init(status: NotificationAuthorization) { self.status = status }

        func authorization() async -> NotificationAuthorization { status }
        func requestAuthorization() async -> Bool {
            if status == .notDetermined { status = .granted }
            return status == .granted
        }
        func pendingIdentifiers() async -> [String] { Array(pending.keys) }
        func remove(_ identifiers: [String]) { for id in identifiers { pending[id] = nil } }
        func add(id: String, body: String, at date: Date, day: Date) async { pending[id] = (body, date) }
    }
#endif

/// Background app refresh before the morning notification.
enum BackgroundRefresh {
    static var identifier: String { (Bundle.main.bundleIdentifier ?? "rideornah") + ".refresh" }
    /// How long before the next notification to ask iOS for a refresh.
    static let lead: TimeInterval = 90 * 60

    static func earliestBegin(beforeNotificationAt fire: Date) -> Date { fire.addingTimeInterval(-lead) }

    static func schedule(beforeNotificationAt fire: Date) {
        let request = BGAppRefreshTaskRequest(identifier: identifier)
        request.earliestBeginDate = earliestBegin(beforeNotificationAt: fire)
        try? BGTaskScheduler.shared.submit(request)
    }
}

/// Replaces every pending ride notification with a new plan.
enum NotificationScheduler {
    static let prefix = "ride."

    static func replace(with plan: [PlannedNotification], in center: any NotificationCentering) async {
        let existing = await center.pendingIdentifiers().filter { $0.hasPrefix(prefix) }
        center.remove(existing)
        for item in plan { await center.add(id: item.id, body: item.body, at: item.fireDate, day: item.day) }
    }
}
