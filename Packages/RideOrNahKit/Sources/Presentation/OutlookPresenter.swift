import Foundation
import RiderSettings
import VerdictEngine
import WeatherData

public struct OutlookRow: Sendable, Equatable {
    public var day: Date
    /// `Wed`.
    public var weekday: String
    /// `Today` or `26 Nov`.
    public var detail: String
    /// Nil when today has nothing left to evaluate.
    public var verdict: Verdict?
    public var summary: String
    public var lowerConfidence: Bool
}

/// The Next 7 days list.
public struct OutlookPresenter: Sendable {
    public var formatter: DisplayFormatter

    public init(formatter: DisplayFormatter) { self.formatter = formatter }

    public func rows(_ outlook: [DayEvaluation], profile: RiderProfile, now: Date) -> [OutlookRow] {
        outlook.map { row($0, profile: profile, now: now) }
    }

    public func row(_ day: DayEvaluation, profile: RiderProfile, now: Date) -> OutlookRow {
        let label = formatter.dayLabel(day.day, now: now)
        return OutlookRow(
            day: day.day, weekday: label.weekday, detail: label.detail, verdict: day.verdict,
            summary: summary(day, profile: profile), lowerConfidence: day.confidence == .lower)
    }

    func summary(_ day: DayEvaluation, profile: RiderProfile) -> String {
        switch day.status {
        case .noRideWindowsRemaining: return "Ride windows over"
        case .noDaylightRemaining: return "No daylight left"
        case .evaluated: break
        }
        switch day.verdict {
        case .unknown?:
            switch day.unknownReason {
            case .forecastTooOld?: return "Forecast too old to call"
            case .missingSunTimes?: return "No sunrise or sunset data"
            default: return "Forecast missing"
            }
        case .ride?:
            return day.hasNoScheduledWindow && !profile.windows.isEmpty
                ? "No ride window scheduled · clear in daylight" : "Clear for all your ride windows"
        default:
            return day.breaches.first.map(formatter.summary) ?? ""
        }
    }
}

public struct HourRow: Sendable, Equatable {
    public var hour: String
    public var temperature: String
    public var feelsLike: String
    public var rainChance: String
    /// `6 · 10`: sustained wind and gusts, without units.
    public var windAndGusts: String
    public var uv: String
    /// A breach mark under the row: severity and what, such as `Gusts 31 mph to the west`.
    public var marks: [(severity: Severity, text: String)]

    public static func == (lhs: HourRow, rhs: HourRow) -> Bool {
        lhs.hour == rhs.hour && lhs.temperature == rhs.temperature && lhs.feelsLike == rhs.feelsLike
            && lhs.rainChance == rhs.rainChance && lhs.windAndGusts == rhs.windAndGusts && lhs.uv == rhs.uv
            && lhs.marks.map(\.text) == rhs.marks.map(\.text) && lhs.marks.map(\.severity) == rhs.marks.map(\.severity)
    }
}

public struct HourSection: Sendable, Equatable {
    public var title: String
    public var verdict: Verdict
    public var hours: [HourRow]
}

public struct DayDetailContent: Sendable, Equatable {
    /// `Friday 27 Nov`.
    public var title: String
    public var verdict: Verdict?
    public var word: String
    public var summary: String
    public var sections: [HourSection]
    public var reasons: [ReasonRow]
    /// `Your ride windows` or `Daylight`.
    public var hoursCaption: String
}

/// One day's evaluated hours and reasons. Values are at the evaluation location; marks cover
/// any point in the radius. Missing values show as `—`, never zero.
public struct DayDetailPresenter: Sendable {
    public var formatter: DisplayFormatter

    public init(formatter: DisplayFormatter) { self.formatter = formatter }

    public func content(_ day: DayEvaluation, snapshot: ForecastSnapshot?, profile: RiderProfile, now: Date)
        -> DayDetailContent
    {
        let center = Dictionary(
            ((snapshot?.samples.first { $0.position == .center }?.hours) ?? []).map { ($0.start, $0) },
            uniquingKeysWith: { first, _ in first })
        let sections = day.windows.filter { !$0.isEnded }.map { window in
            HourSection(
                title: formatter.timeRange(window.interval), verdict: window.verdict,
                hours: window.evaluatedHours.map { hour in
                    let values = center[hour]
                    func show<T>(_ value: T?, _ format: (T) -> String) -> String { value.map(format) ?? "—" }
                    let wind = show(values?.windSpeed) { formatter.speed($0, withUnit: false) }
                    let gust = show(values?.windGust) { formatter.speed($0, withUnit: false) }
                    let marks = day.breaches.filter { $0.range.contains(hour) && $0.range.end != hour }.map { breach in
                        let worst = breach.worstValue.map { " " + formatter.value($0, for: breach.factor) } ?? ""
                        return (
                            breach.severity,
                            "\(formatter.factorName(breach.factor))\(worst) \(formatter.places(breach.positions))"
                        )
                    }
                    return HourRow(
                        hour: formatter.time(hour), temperature: show(values?.temperature, formatter.temperature),
                        feelsLike: show(values?.feelsLike, formatter.temperature),
                        rainChance: show(values?.precipitationChance, formatter.percent),
                        windAndGusts: "\(wind) · \(gust)",
                        uv: show(values?.uvIndex, formatter.index), marks: marks)
                })
        }
        let verdict = day.verdict
        return DayDetailContent(
            title: formatter.longDate(day.day), verdict: verdict, word: verdict.map(VerdictWords.word) ?? "DONE",
            summary: OutlookPresenter(formatter: formatter).summary(day, profile: profile), sections: sections,
            reasons: day.breaches.map {
                ReasonRow(
                    severity: $0.severity, title: formatter.reasonTitle($0), limit: formatter.reasonLimit($0),
                    detail: formatter.reasonDetail($0))
            },
            hoursCaption: day.hasNoScheduledWindow ? "Daylight" : "Your ride windows")
    }
}
