import Presentation
import SwiftUI

/// The pill under a Week row, as the Week board draws it: "Clear 9 AM–4:45 PM" and Add to Calendar.
struct SuggestionPill: View {
    @Environment(RideCalendar.self) private var calendar
    let suggestion: RideSuggestion

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "calendar").foregroundStyle(Theme.accent).accessibilityHidden(true)
            // The day row above already shows the lower-confidence badge; VoiceOver hears it here too.
            Text("Clear \(Text(suggestion.text).bold())").font(.footnote).foregroundStyle(Theme.ink)
                .accessibilityValue(suggestion.lowerConfidence ? "Lower confidence" : "")
            Spacer(minLength: 0)
            AddButton(suggestion: suggestion)
        }
        .padding(.leading, 12)
        .padding(4)
        .background(Theme.accent.opacity(0.08), in: .capsule)
        .overlay(Capsule().strokeBorder(Theme.accent.opacity(0.3)))
    }
}

/// The "Ride suggestion" card on Day detail, as the board draws it.
struct SuggestionCard: View {
    let suggestion: RideSuggestion
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("RIDE SUGGESTION").font(Theme.display(.subheadline, weight: .semibold)).tracking(3)
                .foregroundStyle(Theme.reasonWarm)
                .accessibilityAddTraits(.isHeader)
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(suggestion.text).font(Theme.display(.title, weight: .bold)).foregroundStyle(Theme.accent)
                    Text(detail).font(.footnote).foregroundStyle(Theme.inkSecondary)
                    if suggestion.lowerConfidence {
                        Text("Lower confidence").font(.caption).foregroundStyle(Theme.inkTertiary)
                    }
                }
                Spacer(minLength: 0)
                AddButton(suggestion: suggestion)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.accent.opacity(0.08), in: .rect(cornerRadius: 26))
        .overlay(RoundedRectangle(cornerRadius: 26).strokeBorder(Theme.accent.opacity(0.3)))
    }
}

/// Add to Calendar, or Added once saved.
struct AddButton: View {
    @Environment(RideCalendar.self) private var calendar
    let suggestion: RideSuggestion

    var body: some View {
        Button(suggestion.isAdded ? "Added" : "Add to Calendar") { calendar.add(suggestion.range) }
            .font(.footnote.weight(.semibold))
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 14)
            .frame(minHeight: 44)
            .foregroundStyle(suggestion.isAdded ? Theme.inkSecondary : Theme.ground)
            .background(suggestion.isAdded ? Color.clear : Theme.accent, in: .capsule)
            .disabled(suggestion.isAdded)
            .accessibilityIdentifier(suggestion.isAdded ? "suggestion.added" : "suggestion.add")
    }
}

/// Added rides that now look worse, or can't be checked, shown on Today.
struct AddedRideNotices: View {
    @Environment(RideCalendar.self) private var calendar
    @Environment(ForecastController.self) private var forecast

    var body: some View {
        ForEach(calendar.statuses, id: \.ride.start) { status in
            switch status.state {
            case .stillGood:
                EmptyView()
            case .warning(let text):
                Card {
                    Label(text, systemImage: "exclamationmark.triangle")
                        .font(.subheadline.weight(.semibold)).foregroundStyle(Theme.reasonWarm)
                        .accessibilityIdentifier("addedRide.warning")
                }
            case .notChecked:
                Text(
                    "Your ride \(forecast.formatter.shortDate(status.ride.start)), \(forecast.formatter.timeRange(status.ride.range)): not checked. The forecast is too old to call it."
                )
                .font(.footnote).foregroundStyle(Theme.inkTertiary)
                .accessibilityIdentifier("addedRide.notChecked")
            }
        }
    }
}
