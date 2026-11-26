import Foundation
import RiderSettings
import VerdictEngine

/// Turns SI values, times and places into the short text the screens show.
public struct DisplayFormatter: Sendable {
    public var units: UnitSystem
    public var calendar: Calendar

    public init(units: UnitSystem, calendar: Calendar) {
        self.units = units
        self.calendar = calendar
    }

    // MARK: Values

    public func temperature(_ celsius: Double) -> String {
        "\(Int(Quantity.temperature.display(celsius, in: units).rounded()))°"
    }

    public func speed(_ metresPerSecond: Double, withUnit: Bool = true) -> String {
        let value = "\(Int(Quantity.speed.display(metresPerSecond, in: units).rounded()))"
        return withUnit ? "\(value) \(Quantity.speed.symbol(in: units))" : value
    }

    public func percent(_ fraction: Double) -> String { "\(Int((fraction * 100).rounded()))%" }

    public func distance(_ metres: Double) -> String {
        let value = Quantity.distance.display(metres, in: units)
        let text = value < 10 ? String(format: "%.1f", value) : "\(Int(value.rounded()))"
        return "\(text) \(Quantity.distance.symbol(in: units))"
    }

    public func rate(_ millimetresPerHour: Double) -> String {
        let value = Quantity.precipitationRate.display(millimetresPerHour, in: units)
        return String(format: units == .imperial ? "%.2f" : "%.1f", value) + " "
            + Quantity.precipitationRate.symbol(in: units)
    }

    public func index(_ value: Double) -> String { "\(Int(value.rounded()))" }

    /// A limit's value, or a breach's worst value, in the right form for its factor.
    public func value(_ value: Double, for factor: Factor) -> String {
        switch factor {
        case .precipitationChance, .humidity: percent(value)
        case .precipitationIntensity: rate(value)
        case .cold, .heat, .ice: temperature(value)
        case .wind, .gusts: speed(value)
        case .uv: index(value)
        case .visibility: distance(value)
        case .storm, .wetRoads, .fog, .alert: ""
        }
    }

    // MARK: Time

    /// `7 AM`, `5:30 PM`.
    public func time(_ date: Date) -> String {
        let (hour, minute, suffix) = clock(date)
        return minute == 0 ? "\(hour) \(suffix)" : String(format: "%d:%02d %@", hour, minute, suffix)
    }

    /// `4–7 PM` when both ends share AM or PM, else `11 AM–5:30 PM`.
    public func timeRange(_ interval: DateInterval) -> String {
        let start = clock(interval.start)
        let end = clock(interval.end)
        let startText = start.minute == 0 ? "\(start.hour)" : String(format: "%d:%02d", start.hour, start.minute)
        if start.suffix == end.suffix { return "\(startText)–\(time(interval.end))" }
        return "\(time(interval.start))–\(time(interval.end))"
    }

    private func clock(_ date: Date) -> (hour: Int, minute: Int, suffix: String) {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        let hour24 = parts.hour ?? 0
        return (hour24 % 12 == 0 ? 12 : hour24 % 12, parts.minute ?? 0, hour24 < 12 ? "AM" : "PM")
    }

    /// `Now`, `Ended`, `In 45 min` or `In 8 h`.
    public func relative(_ interval: DateInterval, now: Date) -> String {
        if interval.end <= now { return "Ended" }
        if interval.start <= now { return "Now" }
        let minutes = Int((interval.start.timeIntervalSince(now) / 60).rounded(.up))
        return minutes < 60 ? "In \(minutes) min" : "In \(minutes / 60) h"
    }

    /// `12 min ago`, `5 hours ago`, `just now`.
    public func age(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds / 60)
        if minutes < 1 { return "just now" }
        if minutes < 60 { return "\(minutes) min ago" }
        let hours = minutes / 60
        return hours == 1 ? "1 hour ago" : "\(hours) hours ago"
    }

    /// `10h 08m`.
    public func duration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds / 60)
        return String(format: "%dh %02dm", minutes / 60, minutes % 60)
    }

    static let weekdays = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    static let longWeekdays = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
    static let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

    /// `Wed 25 Nov`.
    public func shortDate(_ date: Date) -> String {
        let parts = calendar.dateComponents([.weekday, .day, .month], from: date)
        return "\(Self.weekdays[(parts.weekday ?? 1) - 1]) \(parts.day ?? 0) \(Self.months[(parts.month ?? 1) - 1])"
    }

    /// `Friday 27 Nov`.
    public func longDate(_ date: Date) -> String {
        let parts = calendar.dateComponents([.weekday, .day, .month], from: date)
        return "\(Self.longWeekdays[(parts.weekday ?? 1) - 1]) \(parts.day ?? 0) \(Self.months[(parts.month ?? 1) - 1])"
    }

    /// The weekday (`Wed`), and `Today` or the date (`26 Nov`).
    public func dayLabel(_ day: Date, now: Date) -> (weekday: String, detail: String) {
        let parts = calendar.dateComponents([.weekday, .day, .month], from: day)
        let weekday = Self.weekdays[(parts.weekday ?? 1) - 1]
        if calendar.isDate(day, inSameDayAs: now) { return (weekday, "Today") }
        return (weekday, "\(parts.day ?? 0) \(Self.months[(parts.month ?? 1) - 1])")
    }

    // MARK: Places

    static let directionNames: [CompassDirection: String] = [
        .n: "north", .ne: "northeast", .e: "east", .se: "southeast", .s: "south", .sw: "southwest", .w: "west",
        .nw: "northwest",
    ]

    public func directionName(_ direction: CompassDirection) -> String { Self.directionNames[direction] ?? "" }

    /// `N, NE and NW`.
    public func directionList(_ directions: [CompassDirection]) -> String {
        let names = directions.sorted().map { String(describing: $0).uppercased() }
        guard names.count > 1 else { return names.first ?? "" }
        return names.dropLast().joined(separator: ", ") + " and " + names.last!
    }

    /// `here`, `to the west`, `to the N, NE and NW`, or `here and to the N`.
    public func places(_ positions: [SamplePosition]) -> String {
        let directions = Array(Set(positions.compactMap(\.direction))).sorted()
        let toward: String? =
            switch directions.count {
            case 0: nil
            case 1: "to the \(directionName(directions[0]))"
            default: "to the \(directionList(directions))"
            }
        switch (positions.contains(.center), toward) {
        case (true, let toward?): return "here and \(toward)"
        case (false, let toward?): return toward
        default: return "here"
        }
    }
}
