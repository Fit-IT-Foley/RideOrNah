import Foundation
import RiderSettings
import VerdictEngine

/// A clear stretch offered as a ride, with Add to Calendar.
public struct RideSuggestion: Sendable, Equatable {
    public var range: DateInterval
    /// `11 AM–5:30 PM`
    public var text: String
    /// Already saved to the calendar, so it isn't offered again.
    public var isAdded: Bool
    public var lowerConfidence: Bool
}

/// Which of a day's opportunities to offer: none while suggestions are off, while the forecast is
/// more than 3 hours old, or on a day that can't be called.
public struct SuggestionPresenter: Sendable {
    public static let freshFor: TimeInterval = 3 * 3600

    public var formatter: DisplayFormatter

    public init(formatter: DisplayFormatter) { self.formatter = formatter }

    public func suggestions(
        for day: DayEvaluation, isOn: Bool, added: [AddedRide], fetchedAt: Date?, now: Date
    ) -> [RideSuggestion] {
        guard isOn, let fetchedAt, now.timeIntervalSince(fetchedAt) <= Self.freshFor, let verdict = day.verdict,
            verdict != .unknown
        else { return [] }
        return day.opportunities.prefix(3).map { range in
            RideSuggestion(
                range: range, text: formatter.timeRange(range), isAdded: added.contains { $0.range == range },
                lowerConfidence: day.confidence == .lower)
        }
    }
}

/// What the system event editor opens with. The rider can change any of it before saving.
public struct CalendarDraft: Sendable, Equatable, Identifiable {
    public var title: String
    public var range: DateInterval
    public var location: String
    public var notes: String

    public var id: Date { range.start }

    public init(
        range: DateInterval, profileName: String, placeName: String, radius: RadiusPreset, fetchedAt: Date,
        formatter: DisplayFormatter
    ) {
        title = "Ride · \(profileName)"
        self.range = range
        location = placeName
        let clear =
            radius == .local
            ? "Clear at \(placeName)." : "Clear at every point in \(radius.label(in: formatter.units))."
        notes = [
            clear, "Forecast from \(formatter.time(fetchedAt)), \(formatter.shortDate(fetchedAt)).",
            "Check Ride or Nah before you leave.",
        ].joined(separator: "\n")
    }
}

/// An added ride, re-checked against a newer forecast.
public struct AddedRideStatus: Sendable, Equatable {
    public enum State: Sendable, Equatable {
        case stillGood
        /// The ride now looks like Maybe or Nah: `Your Saturday ride now looks like Nah: …`
        case warning(String)
        /// The forecast can't call it; never shown as still good.
        case notChecked
    }

    public var ride: AddedRide
    public var state: State
}

public struct AddedRideCheck: Sendable {
    public var formatter: DisplayFormatter

    public init(formatter: DisplayFormatter) { self.formatter = formatter }

    public func status(_ ride: AddedRide, evaluation: RangeEvaluation) -> AddedRideStatus {
        switch evaluation.verdict {
        case .ride:
            return AddedRideStatus(ride: ride, state: .stillGood)
        case .unknown:
            return AddedRideStatus(ride: ride, state: .notChecked)
        case .maybe, .nah:
            let weekday = DisplayFormatter.longWeekdays[formatter.calendar.component(.weekday, from: ride.start) - 1]
            let word = evaluation.verdict == .nah ? "Nah" : "Maybe"
            var text = "Your \(weekday) ride now looks like \(word)"
            if let breach = evaluation.breaches.first {
                let reason = formatter.summary(breach, when: "from \(formatter.time(breach.range.start))")
                text += ": " + reason.prefix(1).lowercased() + reason.dropFirst()
            }
            return AddedRideStatus(ride: ride, state: .warning(text + "."))
        }
    }
}
