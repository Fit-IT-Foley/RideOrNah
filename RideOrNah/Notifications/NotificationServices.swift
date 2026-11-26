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
    func add(id: String, body: String, at date: Date, day: Date, calendarRange: DateInterval?) async
}

/// The Add to Calendar action on a ride notification.
enum CalendarAction {
    static let category = "ride.calendar"
    static let identifier = "calendar.add"

    static func userInfo(_ range: DateInterval) -> [AnyHashable: Any] {
        ["start": range.start.timeIntervalSince1970, "end": range.end.timeIntervalSince1970]
    }

    static func range(from userInfo: [AnyHashable: Any]) -> DateInterval? {
        guard let start = userInfo["start"] as? TimeInterval, let end = userInfo["end"] as? TimeInterval, end > start
        else { return nil }
        return DateInterval(
            start: Date(timeIntervalSince1970: start), end: Date(timeIntervalSince1970: end))
    }
}

final class LiveNotificationCenter: NotificationCentering {
    let center = UNUserNotificationCenter.current()

    init() {
        let add = UNNotificationAction(
            identifier: CalendarAction.identifier, title: "Add to Calendar", options: [.foreground])
        center.setNotificationCategories([
            UNNotificationCategory(identifier: CalendarAction.category, actions: [add], intentIdentifiers: [])
        ])
    }

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

    func add(id: String, body: String, at date: Date, day: Date, calendarRange: DateInterval?) async {
        let content = UNMutableNotificationContent()
        content.body = body
        content.sound = .default
        content.userInfo = ["day": day.timeIntervalSince1970]
        if let calendarRange {
            content.categoryIdentifier = CalendarAction.category
            content.userInfo.merge(CalendarAction.userInfo(calendarRange)) { _, new in new }
        }
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
        private(set) var pending: [String: (body: String, date: Date, calendarRange: DateInterval?)] = [:]

        init(status: NotificationAuthorization) { self.status = status }

        func authorization() async -> NotificationAuthorization { status }
        func requestAuthorization() async -> Bool {
            if status == .notDetermined { status = .granted }
            return status == .granted
        }
        func pendingIdentifiers() async -> [String] { Array(pending.keys) }
        func remove(_ identifiers: [String]) { for id in identifiers { pending[id] = nil } }
        func add(id: String, body: String, at date: Date, day: Date, calendarRange: DateInterval?) async {
            pending[id] = (body, date, calendarRange)
        }
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
        for item in plan {
            await center.add(
                id: item.id, body: item.body, at: item.fireDate, day: item.day, calendarRange: item.calendarRange)
        }
    }
}
