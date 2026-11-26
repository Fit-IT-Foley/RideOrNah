import Presentation
import RiderSettings
import SwiftUI
import VerdictEngine

/// The compass of the ride radius: each direction's wedge in its verdict's color, with the
/// clear directions in words beside it.
struct DirectionCard: View {
    let text: String
    let directions: [DirectionVerdict]
    let radius: String

    var body: some View {
        Card {
            HStack(spacing: 16) {
                Compass(directions: directions)
                    .frame(width: 96, height: 96)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 6) {
                    SectionLabel(text: "Within \(radius)")
                    Text(text).font(Theme.display(.title2, weight: .bold)).foregroundStyle(Theme.ink)
                        .accessibilityIdentifier("today.direction")
                    HStack(spacing: 12) {
                        legend(Theme.accent, "Ride")
                        legend(Theme.nah, "Nah")
                    }
                    .font(.caption)
                    .foregroundStyle(Theme.inkTertiary)
                }
            }
        }
    }

    func legend(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 8, height: 8)
            Text(label)
        }
    }
}

struct Compass: View {
    let directions: [DirectionVerdict]

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) / 2
            for entry in directions {
                let middle = Double(entry.direction.rawValue) * 45 - 90
                var wedge = Path()
                wedge.move(to: center)
                wedge.addArc(
                    center: center, radius: radius, startAngle: .degrees(middle - 21), endAngle: .degrees(middle + 21),
                    clockwise: false)
                wedge.closeSubpath()
                switch entry.verdict {
                case .ride: context.fill(wedge, with: .color(Theme.accent))
                case .nah: context.fill(wedge, with: .color(Theme.nah))
                case .maybe: context.stroke(wedge, with: .color(Theme.accent), lineWidth: 1.5)
                case .unknown:
                    context.stroke(wedge, with: .color(Theme.inkQuiet), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                }
            }
            context.fill(
                Path(ellipseIn: CGRect(x: center.x - 4, y: center.y - 4, width: 8, height: 8)), with: .color(Theme.ink))
        }
    }
}

/// The day from 6 AM to 9 PM, with each ride window in its verdict's color and a "now" tick.
struct DayTimeline: View {
    let windows: [WindowRow]
    let now: Date
    let calendar: Calendar

    var body: some View {
        VStack(spacing: 4) {
            GeometryReader { proxy in
                let width = proxy.size.width
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.08))
                    ForEach(Array(windows.enumerated()), id: \.offset) { _, row in
                        Capsule()
                            .fill(fill(row.verdict))
                            .overlay(row.verdict == .maybe ? Capsule().strokeBorder(Theme.accent, lineWidth: 1.5) : nil)
                            .frame(width: max(x(row.interval.end, width) - x(row.interval.start, width), 4))
                            .offset(x: x(row.interval.start, width))
                            .opacity(row.isEnded ? 0.4 : 1)
                    }
                    Rectangle().fill(Theme.ink).frame(width: 2, height: 16).offset(x: x(now, width))
                }
            }
            .frame(height: 10)
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    ForEach([(6, "6A"), (12, "12P"), (18, "6P"), (21, "9P")], id: \.0) { hour, label in
                        let date = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: now) ?? now
                        Text(label)
                            .fixedSize()
                            .alignmentGuide(.leading) { dimensions in
                                hour == 21 ? dimensions.width : hour == 6 ? 0 : dimensions.width / 2
                            }
                            .offset(x: x(date, proxy.size.width))
                    }
                }
            }
            .frame(height: 14)
            .font(.caption2)
            .foregroundStyle(Theme.inkQuiet)
        }
        .accessibilityHidden(true)
    }

    /// Position of `date` along a bar `width` wide, from 6 AM to 9 PM.
    func x(_ date: Date, _ width: CGFloat) -> CGFloat {
        let start = calendar.date(bySettingHour: 6, minute: 0, second: 0, of: now) ?? now
        return width * CGFloat(min(max(date.timeIntervalSince(start) / (15 * 3600), 0), 1))
    }

    func fill(_ verdict: Verdict) -> Color {
        switch verdict {
        case .nah: Theme.nah
        case .ride: Theme.accent
        default: Theme.accent.opacity(0.22)
        }
    }
}

/// HARD and SOFT reasons, as in "Why nah" and "Why maybe".
struct ReasonsCard: View {
    let title: String
    let reasons: [ReasonRow]

    var body: some View {
        Card {
            SectionLabel(text: title)
            ForEach(Array(reasons.enumerated()), id: \.offset) { _, reason in
                HStack(alignment: .top, spacing: 12) {
                    SeverityTag(severity: reason.severity)
                    VStack(alignment: .leading, spacing: 2) {
                        (Text(reason.title).fontWeight(.semibold)
                            + Text(reason.limit.map { " \($0)" } ?? "").foregroundColor(Theme.inkTertiary))
                            .foregroundStyle(Theme.ink)
                        Text(reason.detail).font(.footnote).foregroundStyle(Theme.inkTertiary)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 4)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("today.reason")
            }
        }
    }
}

struct SeverityTag: View {
    let severity: Severity
    var body: some View {
        Text(severity == .hard ? "HARD" : "SOFT")
            .font(.caption2.weight(.bold))
            .tracking(0.5)
            .frame(width: 44, height: 22)
            .foregroundStyle(severity == .hard ? Theme.ground : Theme.ink)
            .background(severity == .hard ? Theme.nah : .clear, in: .rect(cornerRadius: 6))
            .overlay(severity == .soft ? RoundedRectangle(cornerRadius: 6).strokeBorder(Color.white.opacity(0.4)) : nil)
    }
}

/// When today is over: tomorrow's call.
struct TomorrowCard: View {
    let row: OutlookRow
    var body: some View {
        Card {
            SectionLabel(text: "Tomorrow")
            HStack(spacing: 12) {
                if let verdict = row.verdict { VerdictPill(verdict: verdict) }
                Text(row.summary).font(.subheadline).foregroundStyle(Theme.inkSecondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("today.tomorrow")
    }
}

/// Profile, place or today's radius, chosen from Today's chips.
struct ChoicePicker: View {
    @Environment(AppModel.self) private var model
    @Environment(ForecastController.self) private var forecast
    @Environment(\.dismiss) private var dismiss
    let kind: TodayView.Picker

    var body: some View {
        NavigationStack {
            List {
                if let preferences = model.preferences {
                    switch kind {
                    case .profile:
                        ForEach(preferences.profiles) { profile in
                            choice(profile.name, selected: profile.id == preferences.activeProfileID) {
                                try? model.update { try $0.activate(profile.id) }
                            }
                        }
                    case .place:
                        choice("Current location", selected: preferences.evaluationLocation == .current) {
                            model.update { $0.choose(.current) }
                        }
                        ForEach(preferences.savedLocations) { place in
                            choice(place.name, selected: preferences.evaluationLocation == .saved(place.id)) {
                                model.update { $0.choose(.saved(place.id)) }
                            }
                        }
                    case .radius:
                        let units = preferences.unitPreference.resolved()
                        let current = preferences.radius(on: forecast.clock(), calendar: forecast.calendar)
                        ForEach(RadiusPreset.allCases, id: \.self) { preset in
                            choice(preset.label(in: units), selected: preset == current) {
                                model.update {
                                    $0.setTodayRadius(preset, now: forecast.clock(), calendar: forecast.calendar)
                                }
                            }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.ground)
            .navigationTitle(title)
            .toolbar { Button("Done") { dismiss() } }
        }
    }

    var title: String {
        switch kind {
        case .profile: "Profile"
        case .place: "Location"
        case .radius: "Radius today"
        }
    }

    func choice(_ name: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            action()
            dismiss()
            Task { await forecast.refresh(.foreground) }
        } label: {
            HStack {
                Text(name).foregroundStyle(Theme.ink)
                Spacer()
                if selected { Image(systemName: "checkmark").foregroundStyle(Theme.accent) }
            }
            .frame(minHeight: 44)
        }
        .accessibilityIdentifier("choice.\(name)")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
