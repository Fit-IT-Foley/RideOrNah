import Foundation
import Presentation
import RiderSettings
import Testing
import UIKit
import WeatherData

@testable import RideOrNah

@MainActor
struct NotificationCoordinatorTests {
    static func june(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        Calendar.current.date(from: DateComponents(year: 2026, month: 6, day: day, hour: hour, minute: minute))!
    }

    static func coordinator(clock: MovableClock, status: NotificationAuthorization = .notDetermined) -> (
        NotificationCoordinator, StubNotificationCenter, AppModel
    ) {
        let (forecast, model) = ForecastControllerTests.controller(clock: clock)
        let center = StubNotificationCenter(status: status)
        model.update { $0.notifications.days = .everyDay }
        return (NotificationCoordinator(app: model, forecast: forecast, center: center), center, model)
    }

    // Scenario: ride-notifications: Settings change
    @Test("Settings change")
    func settingsChange() async {
        let clock = MovableClock(Self.june(8, 5))
        let (coordinator, center, model) = Self.coordinator(clock: clock)
        await coordinator.forecast.refresh(.foreground)
        #expect(await coordinator.enable(at: 6 * 60 + 30))
        #expect(center.pending.count == 3)
        #expect(center.pending.values.allSatisfy { Self.hourMinute($0.date) == [6, 30] })
        model.update { $0.notifications.minutesAfterMidnight = 5 * 60 + 45 }
        await coordinator.rebuild()
        #expect(center.pending.count == 3)
        #expect(center.pending.values.allSatisfy { Self.hourMinute($0.date) == [5, 45] })
        #expect(coordinator.next?.fireDate == Self.june(8, 5, 45))
        #expect(coordinator.next?.body.hasPrefix("Ride") == true)
    }

    // Scenario: ride-notifications: Refresh runs in time
    @Test("Refresh runs in time")
    func refreshRunsInTime() async {
        let clock = MovableClock(Self.june(7, 21))
        let (coordinator, _, _) = Self.coordinator(clock: clock)
        await coordinator.forecast.refresh(.foreground)
        #expect(await coordinator.enable(at: 6 * 60 + 30))
        #expect(coordinator.next?.fireDate == Self.june(8, 6, 30))
        #expect(coordinator.next?.body.contains("last night's forecast") == true)
        #expect(BackgroundRefresh.earliestBegin(beforeNotificationAt: Self.june(8, 6, 30)) == Self.june(8, 5))
        clock.set(Self.june(8, 5, 20))
        await coordinator.backgroundRefresh()
        #expect(coordinator.forecast.snapshot?.fetchedAt == Self.june(8, 5, 20))
        #expect(coordinator.next?.fireDate == Self.june(8, 6, 30))
        #expect(coordinator.next?.body.hasPrefix("Ride") == true)
        #expect(coordinator.next?.body.contains("Based on") == false)
    }

    // Scenario: ride-notifications: Denied permission
    @Test("Denied permission")
    func deniedPermission() async {
        let (coordinator, center, model) = Self.coordinator(clock: MovableClock(Self.june(8, 5)), status: .denied)
        #expect(await coordinator.enable(at: 6 * 60 + 30) == false)
        #expect(coordinator.authorization == .denied)
        #expect(model.preferences?.notifications.isEnabled == false)
        #expect(center.pending.isEmpty)
        #expect(AlertsView.permissionNote(for: coordinator.authorization)?.contains("iOS Settings") == true)
        #expect(AlertsView.permissionNote(for: .granted) == nil)
        #expect(URL(string: UIApplication.openNotificationSettingsURLString) != nil)
    }

    // Scenario: ride-notifications: Tap
    @Test("Tap")
    func tap() {
        let model = AppModel.preview()
        model.selectedTab = .alerts
        NotificationRouter(app: model).openToday()
        #expect(model.selectedTab == .today)
    }

    static func hourMinute(_ date: Date) -> [Int] {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
        return [parts.hour ?? -1, parts.minute ?? -1]
    }
}
