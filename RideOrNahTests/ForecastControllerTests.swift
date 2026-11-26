import Foundation
import RiderSettings
import Testing
import WeatherData

@testable import RideOrNah

/// A clock tests can move.
final class MovableClock: @unchecked Sendable {
    private let lock = NSLock()
    private var current: Date
    init(_ date: Date) { current = date }
    var now: Date { lock.withLock { current } }
    func set(_ date: Date) { lock.withLock { current = date } }
    var function: @Sendable () -> Date { { self.now } }
}

@MainActor
struct ForecastControllerTests {
    static func monday(_ hour: Int, _ minute: Int = 0) -> Date {
        Calendar.current.date(from: DateComponents(year: 2026, month: 6, day: 8, hour: hour, minute: minute))!
    }

    static func controller(clock: MovableClock) -> (ForecastController, AppModel) {
        let model = AppModel.preview()
        let cache = ForecastCache(
            directory: FileManager.default.temporaryDirectory.appending(path: "ControllerTests-\(UUID().uuidString)"))
        let controller = ForecastController(
            app: model, source: .fixture(.clearDay), clock: clock.function, cache: cache, budget: nil)
        return (controller, model)
    }

    // Scenario: verdict-display: Pull too soon
    @Test("Pull too soon")
    func pullTooSoon() async {
        let clock = MovableClock(Self.monday(6))
        let (controller, _) = Self.controller(clock: clock)
        await controller.refresh(.foreground)
        #expect(controller.message == nil)
        clock.set(Self.monday(6, 5))
        await controller.refresh(.manual)
        #expect(controller.message == "Already up to date")
        #expect(controller.snapshot?.outcome == .alreadyCurrent)
    }

    // Scenario: verdict-display: Switching to a smaller radius
    @Test("Switching to a smaller radius")
    func switchingToASmallerRadius() async {
        let clock = MovableClock(Self.monday(6))
        let (controller, model) = Self.controller(clock: clock)
        await controller.refresh(.foreground)
        #expect(controller.today?.word == "RIDE")
        model.update { $0.setTodayRadius(.local, now: clock.now, calendar: .current) }
        await controller.refresh(.foreground)
        #expect(controller.snapshot?.samples.count == 1)
        #expect(controller.today?.word == "RIDE")
        #expect(controller.today?.directions == nil)
    }

    // Scenario: verdict-display: Midnight with the app open
    @Test("Midnight with the app open")
    func midnightWithTheAppOpen() async {
        let clock = MovableClock(Self.monday(23, 59))
        let (controller, model) = Self.controller(clock: clock)
        model.update { $0.setTodayRadius(.km160, now: clock.now, calendar: .current) }
        await controller.refresh(.foreground)
        clock.set(Self.monday(23, 59).addingTimeInterval(120))
        controller.handleDayChange()
        #expect(model.preferences?.todayRadius == nil)
        #expect(model.preferences?.radius(on: clock.now, calendar: .current) == .km40)
        #expect(Calendar.current.isDate(controller.outlook?.first?.day ?? .distantPast, inSameDayAs: clock.now))
    }
}
