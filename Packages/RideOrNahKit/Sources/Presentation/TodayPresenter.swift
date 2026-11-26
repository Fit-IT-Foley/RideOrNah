import Foundation
import RiderSettings
import VerdictEngine
import WeatherData

public struct ReasonRow: Sendable, Equatable {
    public var severity: Severity
    public var title: String
    public var limit: String?
    public var detail: String
}

public struct WindowRow: Sendable, Equatable {
    public var interval: DateInterval
    public var timeRange: String
    public var relative: String
    public var verdict: Verdict
    public var note: String
    public var isEnded: Bool
}

public struct RoomRow: Sendable, Equatable {
    public var title: String
    public var worst: String
    public var maybeAt: String
}

public struct CurrentConditions: Sendable, Equatable {
    public var air: String
    public var feelsLike: String
    public var rainChance: String
}

public struct DaylightContent: Sendable, Equatable {
    public var sunrise: String
    public var sunset: String
    public var length: String
}

public enum UnknownCause: String, Sendable, Equatable {
    case noLocation, offline, forecastTooOld, budgetPaused, serviceUnavailable, notAuthorized, missingData
}

public struct UnknownContent: Sendable, Equatable {
    public var cause: UnknownCause
    public var title: String
    public var detail: String
    /// The next step's button title, or nil when there's nothing to do but wait.
    public var action: String?
}

public struct TodayContent: Sendable, Equatable {
    /// Nil when nothing is left to evaluate today.
    public var verdict: Verdict?
    /// `RIDE`, `MAYBE`, `NAH`, `CAN'T TELL`, or `DONE`.
    public var word: String
    public var summary: String
    /// `No ride planned today`, `Today's riding windows are over`, and so on.
    public var note: String?
    /// Shown when today is over.
    public var tomorrow: OutlookRow?
    public var windows: [WindowRow]
    public var reasons: [ReasonRow]
    public var directions: [DirectionVerdict]?
    public var directionText: String?
    public var current: CurrentConditions?
    public var room: [RoomRow]
    public var daylight: DaylightContent?
    /// `Home · Wed 25 Nov · Updated 12 min ago`.
    public var freshness: String
    public var staleNote: String?
    public var notes: [String]
    public var unknown: UnknownContent?
}

/// Everything the Today screen says, from the engine's outlook and the forecast snapshot.
public struct TodayPresenter: Sendable {
    public var formatter: DisplayFormatter

    public init(formatter: DisplayFormatter) { self.formatter = formatter }

    /// - Parameters:
    ///   - outlook: The engine's outlook, or nil when there was no forecast to evaluate.
    ///   - place: The resolved evaluation place, or nil when there's no location.
    public func content(
        outlook: [DayEvaluation]?, snapshot: ForecastSnapshot?, place: ResolvedLocation?, profile: RiderProfile,
        radius: RadiusPreset, now: Date
    ) -> TodayContent {
        var content = TodayContent(
            verdict: nil, word: "", summary: "", note: nil, tomorrow: nil, windows: [], reasons: [], directions: nil,
            directionText: nil, current: nil, room: [], daylight: nil,
            freshness: freshnessLine(place: place, snapshot: snapshot, now: now), staleNote: nil, notes: [],
            unknown: nil)
        content.notes = notes(snapshot: snapshot, today: outlook?.first)
        content.current = current(snapshot: snapshot, now: now)
        content.daylight = daylight(snapshot: snapshot, now: now)

        guard place != nil else { return unknown(.noLocation, into: content) }
        guard let outlook, let today = outlook.first else {
            return unknown(cause(for: snapshot?.outcome), into: content)
        }
        if case .stale = today.freshness { content.staleNote = "Based on an older forecast" }

        switch today.status {
        case .noRideWindowsRemaining, .noDaylightRemaining:
            content.word = "DONE"
            content.summary =
                today.status == .noRideWindowsRemaining ? "Today's riding windows are over" : "No daylight left today"
            content.tomorrow =
                outlook.count > 1
                ? OutlookPresenter(formatter: formatter).row(outlook[1], profile: profile, now: now) : nil
            content.windows = windowRows(today, radius: radius, now: now)
            return content
        case .evaluated:
            break
        }
        guard let verdict = today.verdict else { return content }
        if verdict == .unknown {
            return unknown(today.unknownReason == .forecastTooOld ? .forecastTooOld : .missingData, into: content)
        }

        content.verdict = verdict
        content.word = VerdictWords.word(verdict)
        content.summary =
            verdict == .ride ? "Clear for all your ride windows" : (today.breaches.first.map(formatter.summary) ?? "")
        if today.hasNoScheduledWindow && !profile.windows.isEmpty {
            content.note = "No ride planned today · judged on daylight"
        }
        content.windows = windowRows(today, radius: radius, now: now)
        content.reasons = today.breaches.map {
            ReasonRow(
                severity: $0.severity, title: formatter.reasonTitle($0), limit: formatter.reasonLimit($0),
                detail: formatter.reasonDetail($0))
        }
        content.directions = today.directions
        if radius != .local, verdict != .ride, today.directions != nil {
            content.directionText =
                today.clearDirections.isEmpty
                ? "No direction in \(radius.label(in: formatter.units)) is clear"
                : "Clear to the \(formatter.directionList(today.clearDirections))"
        }
        if verdict == .ride { content.room = room(today, snapshot: snapshot, limits: profile.limits) }
        return content
    }

    // MARK: Parts

    func unknown(_ cause: UnknownCause, into content: TodayContent) -> TodayContent {
        var content = content
        content.verdict = .unknown
        content.word = VerdictWords.word(.unknown)
        let (title, detail, action) = Self.unknownText[cause]!
        content.unknown = UnknownContent(cause: cause, title: title, detail: detail, action: action)
        content.summary = title
        return content
    }

    static let unknownText: [UnknownCause: (String, String, String?)] = [
        .noLocation: (
            "Add a location", "Ride or Nah needs your location or a saved place to check the weather.", "Add a place"
        ),
        .offline: ("Can't check the weather offline", "Connect to the internet and try again.", "Try again"),
        .forecastTooOld: ("The forecast is too old", "Refresh to get today's call.", "Refresh"),
        .budgetPaused: (
            "Refreshing is paused for today", "You've reached today's weather limit. Check again tomorrow.", nil
        ),
        .serviceUnavailable: ("Apple Weather isn't responding", "Try again in a little while.", "Try again"),
        .notAuthorized: ("Weather isn't available in this version", "Update Ride or Nah from the App Store.", nil),
        .missingData: ("Part of today's forecast is missing", "Refresh to try again.", "Refresh"),
    ]

    func cause(for outcome: ForecastOutcome?) -> UnknownCause {
        switch outcome {
        case .offline: .offline
        case .notAuthorized: .notAuthorized
        case .serviceUnavailable: .serviceUnavailable
        case .budgetLimited: .budgetPaused
        default: .missingData
        }
    }

    func freshnessLine(place: ResolvedLocation?, snapshot: ForecastSnapshot?, now: Date) -> String {
        var parts = [place?.name, formatter.shortDate(now)].compactMap { $0 }
        if let fetchedAt = snapshot?.fetchedAt {
            parts.append("Updated \(formatter.age(now.timeIntervalSince(fetchedAt)))")
        }
        return parts.joined(separator: " · ")
    }

    func notes(snapshot: ForecastSnapshot?, today: DayEvaluation?) -> [String] {
        var notes: [String] = []
        switch snapshot?.outcome {
        case .budgetLimited where snapshot?.fetchedAt != nil: notes.append("Refreshing is paused until tomorrow")
        case .offline where snapshot?.fetchedAt != nil: notes.append("Offline · showing the last forecast")
        default: break
        }
        if case .partial(let missing) = today?.coverage, !missing.isEmpty {
            notes.append("Couldn't check the \(missing.map(formatter.directionName).joined(separator: ", "))")
        }
        if today?.notChecked.contains(.alert) == true { notes.append("Severe weather alerts aren't available here") }
        return notes
    }

    func windowRows(_ day: DayEvaluation, radius: RadiusPreset, now: Date) -> [WindowRow] {
        day.windows.map { window in
            let note =
                window.breaches.first.map(formatter.windowNote)
                ?? (window.verdict == .ride
                    ? (radius == .local ? "Clear here" : "Clear everywhere in \(radius.label(in: formatter.units))")
                    : "")
            return WindowRow(
                interval: window.interval, timeRange: formatter.timeRange(window.interval),
                relative: formatter.relative(window.interval, now: now), verdict: window.verdict, note: note,
                isEnded: window.isEnded)
        }
    }

    func centerHours(_ snapshot: ForecastSnapshot?) -> [HourConditions] {
        snapshot?.samples.first { $0.position == .center }?.hours ?? []
    }

    func current(snapshot: ForecastSnapshot?, now: Date) -> CurrentConditions? {
        guard
            let hour = centerHours(snapshot).first(where: { $0.start <= now && now < $0.start.addingTimeInterval(3600) }
            )
        else {
            return nil
        }
        return CurrentConditions(
            air: hour.temperature.map(formatter.temperature) ?? "—",
            feelsLike: hour.feelsLike.map(formatter.temperature) ?? "—",
            rainChance: hour.precipitationChance.map(formatter.percent) ?? "—")
    }

    func daylight(snapshot: ForecastSnapshot?, now: Date) -> DaylightContent? {
        guard let sun = snapshot?.sun.first(where: { formatter.calendar.isDate($0.day, inSameDayAs: now) }),
            let sunrise = sun.sunrise, let sunset = sun.sunset, sunset > sunrise
        else { return nil }
        return DaylightContent(
            sunrise: formatter.time(sunrise), sunset: formatter.time(sunset),
            length: formatter.duration(sunset.timeIntervalSince(sunrise)))
    }

    /// Worst rain chance, gusts, cold and UV in today's counted hours at any point, next to the
    /// soft limit that would make it a Maybe.
    func room(_ day: DayEvaluation, snapshot: ForecastSnapshot?, limits: Limits) -> [RoomRow] {
        let hours = Set(day.windows.filter { !$0.isEnded }.flatMap(\.evaluatedHours))
        let values = (snapshot?.samples ?? []).flatMap(\.hours).filter { hours.contains($0.start) }
        var rows: [RoomRow] = []
        func add(_ title: String, _ factor: Factor, _ limit: ThresholdLimit, _ worst: Double?) {
            guard limit.isEnabled, let soft = limit.soft, let worst else { return }
            rows.append(
                RoomRow(
                    title: title, worst: formatter.value(worst, for: factor),
                    maybeAt: "Maybe at \(formatter.value(soft, for: factor))"))
        }
        if limits.precipitation.isEnabled {
            add(
                "Rain chance", .precipitationChance, limits.precipitation.chance,
                values.compactMap(\.precipitationChance).max())
        }
        add("Gusts", .gusts, limits.gusts, values.compactMap(\.windGust).max())
        add("Coldest hour", .cold, limits.cold, values.compactMap(\.temperature).min())
        add("UV index", .uv, limits.uv, values.compactMap(\.uvIndex).max())
        return rows
    }
}

public enum VerdictWords {
    public static func word(_ verdict: Verdict) -> String {
        switch verdict {
        case .ride: "RIDE"
        case .maybe: "MAYBE"
        case .nah: "NAH"
        case .unknown: "CAN'T TELL"
        }
    }

    /// For VoiceOver: the verdict in words, never a color.
    public static func spoken(_ verdict: Verdict) -> String {
        switch verdict {
        case .ride: "Ride"
        case .maybe: "Maybe"
        case .nah: "Nah"
        case .unknown: "Can't tell"
        }
    }
}
