import Foundation
import RiderSettings
import VerdictEngine

public struct PlannedNotification: Sendable, Equatable {
    /// `ride.2026-06-08`, one per day.
    public var id: String
    public var fireDate: Date
    /// Start of the day the notification is about.
    public var day: Date
    public var body: String
    /// The day's longest ride opportunity, for the Add to Calendar action. Only set while ride
    /// suggestions are on and the forecast will be no more than 3 hours old at delivery.
    public var calendarRange: DateInterval? = nil
}

/// The daily ride notifications for the next three selected days, built on the phone from the
/// newest forecast in hand. Delivery never waits on a refresh, so each body says how old its
/// forecast will be when it arrives, and gives no verdict when that's too old.
public struct NotificationPlanner: Sendable {
    public static let count = 3
    public static let staleAfter: TimeInterval = 3 * 3600
    public static let tooOldAfter: TimeInterval = 12 * 3600
    public static let tooOldBody = "Open Ride or Nah for today's verdict. The last forecast is too old to call it."

    public var formatter: DisplayFormatter

    public init(formatter: DisplayFormatter) { self.formatter = formatter }

    public func plan(
        settings: NotificationSettings, profile: RiderProfile, outlook: [DayEvaluation]?, fetchedAt: Date?, now: Date,
        suggestions: Bool = false
    ) -> [PlannedNotification] {
        guard settings.isEnabled else { return [] }
        let calendar = formatter.calendar
        let weekdays = settings.weekdays(for: profile)
        var planned: [PlannedNotification] = []
        var day = calendar.startOfDay(for: now)
        // Three weeks always holds three of any selected weekday.
        for _ in 0..<21 where planned.count < Self.count {
            defer { day = calendar.date(byAdding: .day, value: 1, to: day)! }
            guard weekdays.contains(calendar.component(.weekday, from: day)),
                let fire = calendar.date(
                    bySettingHour: settings.minutesAfterMidnight / 60, minute: settings.minutesAfterMidnight % 60,
                    second: 0, of: day),
                fire > now
            else { continue }
            let evaluation = outlook?.first { calendar.isDate($0.day, inSameDayAs: day) }
            planned.append(
                PlannedNotification(
                    id: "ride.\(Self.key(day, calendar: calendar))", fireDate: fire, day: day,
                    body: body(evaluation, fetchedAt: fetchedAt, fire: fire),
                    calendarRange: suggestions
                        ? calendarRange(evaluation, fetchedAt: fetchedAt, fire: fire) : nil))
        }
        return planned
    }

    func calendarRange(_ day: DayEvaluation?, fetchedAt: Date?, fire: Date) -> DateInterval? {
        guard let day, let fetchedAt, fire.timeIntervalSince(fetchedAt) <= Self.staleAfter, let verdict = day.verdict,
            verdict != .unknown
        else { return nil }
        return day.opportunities.first
    }

    func body(_ day: DayEvaluation?, fetchedAt: Date?, fire: Date) -> String {
        guard let day, let fetchedAt, fire.timeIntervalSince(fetchedAt) <= Self.tooOldAfter, let verdict = day.verdict,
            verdict != .unknown
        else { return Self.tooOldBody }
        var text: String
        switch verdict {
        case .ride:
            let windows = day.windows.filter { !$0.isEnded }.map { formatter.timeRange($0.interval) }
            text = windows.isEmpty ? "Ride: clear all day." : "Ride: clear \(Self.list(windows))."
        default:
            let word = VerdictWords.spoken(verdict)
            text = "\(word): \(day.breaches.first.map(reason) ?? "check the app")."
            if !day.clearDirections.isEmpty {
                let clear =
                    day.clearDirections.count == 1
                    ? formatter.directionName(day.clearDirections[0]) : formatter.directionList(day.clearDirections)
                text += " Clear to the \(clear)."
            }
        }
        let age = fire.timeIntervalSince(fetchedAt)
        if age > Self.staleAfter { text += " " + ageNote(fetchedAt: fetchedAt, fire: fire) }
        return text
    }

    /// `rain likely 7–9 AM (80%)` where the evaluation location is affected, else the worst value
    /// and where: `gusts up to 34 mph to the west, 4–6 PM`.
    func reason(_ breach: Breach) -> String {
        let text =
            breach.positions.contains(.center)
            ? formatter.summary(breach)
            : "\(formatter.reasonTitle(breach)) \(formatter.places(breach.positions)), \(formatter.timeRange(breach.range))"
        return text.prefix(1).lowercased() + text.dropFirst()
    }

    func ageNote(fetchedAt: Date, fire: Date) -> String {
        let calendar = formatter.calendar
        let previousEvening =
            calendar.isDate(fetchedAt, inSameDayAs: calendar.date(byAdding: .day, value: -1, to: fire)!)
            && calendar.component(.hour, from: fetchedAt) >= 17
        if previousEvening { return "Based on last night's forecast." }
        return "Based on a forecast from \(Int(fire.timeIntervalSince(fetchedAt) / 3600)) hours earlier."
    }

    static func list(_ items: [String]) -> String {
        guard items.count > 1 else { return items.first ?? "" }
        return items.dropLast().joined(separator: ", ") + " and " + items.last!
    }

    static func key(_ day: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: day)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
}
