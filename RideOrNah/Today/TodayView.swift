import Presentation
import RiderSettings
import SwiftUI
import VerdictEngine

/// Today's call, as the "Today — Nah" and "Today — Ride" design boards draw it.
struct TodayView: View {
    @Environment(AppModel.self) private var model
    @Environment(ForecastController.self) private var forecast
    @Binding var tab: AppTab
    @State private var showsSettings = false
    @State private var picker: Picker?
    @ScaledMetric(relativeTo: .largeTitle) private var verdictSize = 150

    enum Picker: String, Identifiable {
        case profile, place, radius
        var id: String { rawValue }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                if let preferences = model.preferences { chips(preferences) }
                if let today = forecast.today {
                    freshness(today)
                    if let unknown = today.unknown {
                        unknownCard(unknown)
                    } else {
                        hero(today)
                        if let current = today.current { currentRow(current) }
                        if let text = today.directionText, let directions = today.directions {
                            DirectionCard(text: text, directions: directions, radius: radiusLabel)
                        }
                        if let tomorrow = today.tomorrow { TomorrowCard(row: tomorrow) }
                        if !today.windows.isEmpty { windowsCard(today) }
                        if !today.reasons.isEmpty {
                            ReasonsCard(title: "Why \((today.word).lowercased())", reasons: today.reasons)
                        }
                        if !today.room.isEmpty { roomCard(today.room) }
                        if let daylight = today.daylight, today.verdict == .ride { daylightCard(daylight) }
                    }
                    Button {
                        tab = .week
                    } label: {
                        Label("See the next 7 days", systemImage: "chevron.right")
                            .labelStyle(TrailingIconLabelStyle())
                            .font(Theme.display(.headline, weight: .bold))
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    .accessibilityIdentifier("today.week")
                }
                WeatherAttributionView(info: forecast.attribution).frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .refreshable { await forecast.refresh(.manual) }
        .background(Theme.ground)
        .accessibilityIdentifier("today.screen")
        .sheet(isPresented: $showsSettings) { SettingsView() }
        .sheet(item: $picker) { picker in
            ChoicePicker(kind: picker)
                .presentationDetents([.medium, .large])
        }
        .overlay(alignment: .top) {
            if let message = forecast.message {
                Text(message)
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 14)
                    .frame(minHeight: 36)
                    .foregroundStyle(Theme.ink)
                    .adaptiveSurface(in: .capsule)
                    .accessibilityIdentifier("today.message")
            }
        }
    }

    var radiusLabel: String {
        guard let preferences = model.preferences else { return "" }
        return preferences.radius(on: forecast.clock(), calendar: forecast.calendar)
            .label(in: preferences.unitPreference.resolved())
    }

    var header: some View {
        HStack {
            Wordmark()
            Spacer()
            Button {
                showsSettings = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.title3)
                    .frame(width: 44, height: 44)
                    .foregroundStyle(Theme.ink)
                    .adaptiveSurface(in: .circle)
            }
            .accessibilityLabel("Settings")
            .accessibilityIdentifier("root.settings")
        }
    }

    func chips(_ preferences: Preferences) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Chip(
                    systemImage: "person.fill", title: preferences.activeProfile.name,
                    accessibilityLabel: "Profile: \(preferences.activeProfile.name). Change profile"
                ) { picker = .profile }
                .accessibilityIdentifier("today.profileChip")
                Chip(
                    systemImage: "mappin", title: forecast.place?.name ?? "Add a place",
                    accessibilityLabel: "Location: \(forecast.place?.name ?? "none"). Change location"
                ) { picker = .place }
                .accessibilityIdentifier("today.placeChip")
                Chip(
                    systemImage: "scope", title: radiusLabel,
                    accessibilityLabel: "Radius today: \(radiusLabel). Change radius"
                ) {
                    picker = .radius
                }
                .accessibilityIdentifier("today.radiusChip")
            }
        }
    }

    func freshness(_ today: TodayContent) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(today.freshness).font(.footnote).foregroundStyle(Theme.inkSecondary)
                .accessibilityIdentifier("today.freshness")
            if let stale = today.staleNote {
                Label(stale, systemImage: "clock.arrow.circlepath").font(.footnote.weight(.semibold)).foregroundStyle(
                    Theme.reasonWarm
                )
                .accessibilityIdentifier("today.stale")
            }
            ForEach(today.notes, id: \.self) { note in
                Label(note, systemImage: "info.circle").font(.footnote).foregroundStyle(Theme.inkTertiary)
                    .accessibilityIdentifier("today.note")
            }
        }
    }

    func hero(_ today: TodayContent) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Rectangle().fill(Theme.inkSecondary).frame(width: 28, height: 1)
                SectionLabel(text: "Today's call")
            }
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text(today.word)
                Text(".").foregroundStyle(today.verdict == .nah ? Theme.nah : Theme.accent)
            }
            .font(.system(size: verdictSize, weight: .black).width(.compressed))
            .foregroundStyle(heroColor(today.verdict))
            .lineLimit(1)
            .minimumScaleFactor(0.3)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(today.verdict.map(VerdictWords.spoken) ?? "Done for today")
            .accessibilityIdentifier("today.word")
            Text(today.summary)
                .font(Theme.reason())
                .foregroundStyle(today.verdict == .nah ? Theme.nah : Theme.reasonWarm)
                .accessibilityIdentifier("today.summary")
            if let note = today.note {
                Text(note).font(.subheadline).foregroundStyle(Theme.inkTertiary).accessibilityIdentifier(
                    "today.dayNote")
            }
        }
        .padding(.top, 8)
    }

    func heroColor(_ verdict: Verdict?) -> Color {
        switch verdict {
        case .nah?: Theme.nahInk
        case .ride?: Theme.accent
        default: Theme.ink
        }
    }

    func currentRow(_ current: CurrentConditions) -> some View {
        HStack(spacing: 0) {
            figure(current.air, "Air now")
            Divider().overlay(Theme.rule)
            figure(current.feelsLike, "Feels like")
            Divider().overlay(Theme.rule)
            figure(current.rainChance, "Rain chance")
        }
        .padding(.vertical, 12)
        .overlay(alignment: .top) { Rectangle().fill(Theme.rule).frame(height: 1) }
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.rule).frame(height: 1) }
        .accessibilityElement(children: .combine)
    }

    func figure(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(Theme.display(.largeTitle, weight: .medium)).foregroundStyle(Theme.ink)
            Text(label).font(.footnote).foregroundStyle(Theme.inkTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 12)
    }

    func unknownCard(_ unknown: UnknownContent) -> some View {
        Card {
            Text(VerdictWords.word(.unknown))
                .font(Theme.display(.largeTitle))
                .foregroundStyle(Theme.inkQuiet)
                .accessibilityLabel("Can't tell")
                .accessibilityIdentifier("today.word")
            Text(unknown.title).font(.title3.weight(.semibold)).foregroundStyle(Theme.ink)
                .accessibilityIdentifier("today.unknown.title")
            Text(unknown.detail).foregroundStyle(Theme.inkSecondary)
            if let action = unknown.action {
                Button(action) {
                    if unknown.cause == .noLocation {
                        showsSettings = true
                    } else {
                        Task { await forecast.refresh(.manual) }
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .accessibilityIdentifier("today.unknown.action")
            }
        }
    }

    func windowsCard(_ today: TodayContent) -> some View {
        Card {
            HStack {
                SectionLabel(text: "Your ride windows")
                Spacer()
                Text(model.preferences?.activeProfile.name ?? "").font(.footnote).foregroundStyle(Theme.inkTertiary)
            }
            DayTimeline(windows: today.windows, now: forecast.clock(), calendar: forecast.calendar)
            ForEach(Array(today.windows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(row.timeRange).font(Theme.display(.title3, weight: .semibold)).foregroundStyle(Theme.ink)
                        Text(row.relative).font(.caption.weight(.semibold))
                            .foregroundStyle(row.relative == "Now" ? Theme.accent : Theme.inkTertiary)
                    }
                    .frame(minWidth: 96, alignment: .leading)
                    VerdictPill(verdict: row.isEnded ? .unknown : row.verdict)
                        .opacity(row.isEnded ? 0.5 : 1)
                    Text(row.isEnded ? "Ended" : row.note).font(.footnote).foregroundStyle(Theme.inkSecondary)
                    Spacer(minLength: 0)
                }
                .padding(.top, 8)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("today.window")
            }
        }
    }

    func roomCard(_ rows: [RoomRow]) -> some View {
        Card {
            HStack {
                SectionLabel(text: "Room to your limits")
                Spacer()
                Text("Worst in your windows").font(.footnote).foregroundStyle(Theme.inkTertiary)
            }
            ForEach(rows, id: \.title) { row in
                HStack {
                    Text(row.title).foregroundStyle(Theme.inkSecondary)
                    Spacer()
                    Text(row.worst).font(Theme.display(.title3, weight: .bold)).foregroundStyle(Theme.ink)
                    Text(row.maybeAt).font(.footnote).foregroundStyle(Theme.inkTertiary).frame(
                        minWidth: 96, alignment: .trailing)
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("today.room")
            }
        }
    }

    func daylightCard(_ daylight: DaylightContent) -> some View {
        Card {
            HStack {
                SectionLabel(text: "Daylight")
                Spacer()
                Text("\(daylight.length) of light").font(.footnote).foregroundStyle(Theme.inkTertiary)
            }
            HStack {
                Label("Sunrise \(daylight.sunrise)", systemImage: "sunrise")
                Spacer()
                Label("Sunset \(daylight.sunset)", systemImage: "sunset")
            }
            .font(.subheadline)
            .foregroundStyle(Theme.ink)
        }
        .accessibilityIdentifier("today.daylight")
    }
}

/// Puts the icon after the title.
struct TrailingIconLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 6) {
            configuration.title
            configuration.icon
        }
    }
}
