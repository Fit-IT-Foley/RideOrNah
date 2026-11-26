import Foundation
import Presentation
import Testing

@testable import RideOrNah

@MainActor
struct RideCalendarTests {
    // Scenario: ride-calendar: Morning action
    @Test("Morning action")
    func morningAction() async {
        let clock = MovableClock(NotificationCoordinatorTests.june(8, 6))
        let (forecast, model) = ForecastControllerTests.controller(clock: clock)
        await forecast.refresh(.foreground)
        let calendar = RideCalendar(app: model, forecast: forecast)
        let router = NotificationRouter(app: model)
        router.addToCalendar = { calendar.add($0) }
        model.selectedTab = .week
        let range = DateInterval(
            start: NotificationCoordinatorTests.june(8, 10), end: NotificationCoordinatorTests.june(8, 15))
        router.handle(action: CalendarAction.identifier, userInfo: CalendarAction.userInfo(range))
        #expect(model.selectedTab == .today)
        #expect(calendar.draft?.range == range)
        #expect(calendar.draft?.title == "Ride · My Bike")
    }

    @Test("Only saved rides are remembered")
    func onlySavedRidesAreRemembered() async {
        let clock = MovableClock(NotificationCoordinatorTests.june(8, 6))
        let (forecast, model) = ForecastControllerTests.controller(clock: clock)
        await forecast.refresh(.foreground)
        model.update { $0.rideSuggestions = true }
        let calendar = RideCalendar(app: model, forecast: forecast)
        guard let first = calendar.suggestions(for: NotificationCoordinatorTests.june(9, 12)).first else {
            Issue.record("Tuesday should have a suggestion")
            return
        }
        calendar.add(first.range)
        calendar.finish(saved: false)
        #expect(calendar.added.isEmpty)
        calendar.add(first.range)
        calendar.finish(saved: true)
        #expect(calendar.added.map(\.range) == [first.range])
        #expect(calendar.suggestions(for: NotificationCoordinatorTests.june(9, 12)).first?.isAdded == true)
        #expect(model.store.addedRides.count == 1)
    }

    @Test("Suggestions follow the setting")
    func suggestionsFollowTheSetting() async {
        let clock = MovableClock(NotificationCoordinatorTests.june(8, 6))
        let (forecast, model) = ForecastControllerTests.controller(clock: clock)
        await forecast.refresh(.foreground)
        let calendar = RideCalendar(app: model, forecast: forecast)
        #expect(calendar.suggestions(for: NotificationCoordinatorTests.june(9, 12)).isEmpty)
        model.update { $0.rideSuggestions = true }
        #expect(!calendar.suggestions(for: NotificationCoordinatorTests.june(9, 12)).isEmpty)
        forecast.setLocked(true)
        #expect(calendar.suggestions(for: NotificationCoordinatorTests.june(9, 12)).isEmpty)
    }
}
