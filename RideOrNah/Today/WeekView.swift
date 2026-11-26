import Presentation
import SwiftUI
import VerdictEngine

/// Next 7 days, as the design board draws it; each day opens its detail.
struct WeekView: View {
    @Environment(AppModel.self) private var model
    @Environment(ForecastController.self) private var forecast

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Wordmark()
                        Spacer()
                        if let today = forecast.today {
                            Text(today.freshness.components(separatedBy: " · ").last ?? "").font(.footnote)
                                .foregroundStyle(Theme.inkTertiary)
                        }
                    }
                    HStack(alignment: .firstTextBaseline, spacing: 0) {
                        Text("NEXT 7 DAYS")
                        Text(".").foregroundStyle(Theme.accent)
                    }
                    .font(Theme.display(.largeTitle))
                    .foregroundStyle(Theme.ink)
                    .padding(.top, 14)
                    .accessibilityAddTraits(.isHeader)
                    if let preferences = model.preferences {
                        Text("\(preferences.activeProfile.name) · \(forecast.place?.name ?? "No place")")
                            .font(.subheadline).foregroundStyle(Theme.inkSecondary).padding(.top, 6)
                    }
                    VStack(spacing: 0) {
                        ForEach(forecast.outlookRows, id: \.day) { row in
                            NavigationLink(value: row.day) { WeekRow(row: row) }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("week.row")
                        }
                    }
                    .padding(.top, 16)
                    if forecast.outlookRows.isEmpty, let unknown = forecast.today?.unknown {
                        Text(unknown.title).foregroundStyle(Theme.inkSecondary).padding(.top, 16)
                    }
                    WeatherAttributionView(info: forecast.attribution).frame(maxWidth: .infinity).padding(.top, 20)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .refreshable { await forecast.refresh(.manual) }
            .background(Theme.ground)
            .navigationDestination(for: Date.self) { day in DayDetailView(day: day) }
            .toolbar(.hidden, for: .navigationBar)
        }
        .accessibilityIdentifier("week.screen")
    }
}

struct WeekRow: View {
    let row: OutlookRow

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(row.weekday).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
                Text(row.detail).font(.caption).foregroundStyle(Theme.inkQuiet)
            }
            .frame(width: 50, alignment: .leading)
            if let verdict = row.verdict {
                VerdictPill(verdict: verdict).frame(width: 84)
            } else {
                Spacer().frame(width: 84)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(row.summary).font(.subheadline).foregroundStyle(Theme.inkSecondary)
                if row.lowerConfidence {
                    Text("Lower confidence")
                        .font(.caption2)
                        .foregroundStyle(Theme.inkTertiary)
                        .padding(.horizontal, 8)
                        .frame(minHeight: 20)
                        .overlay(
                            Capsule().strokeBorder(
                                Color.white.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                        )
                        .accessibilityIdentifier("week.lowerConfidence")
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").foregroundStyle(Theme.inkQuiet).padding(.top, 4)
        }
        .padding(.vertical, 14)
        .overlay(alignment: .top) { Rectangle().fill(Theme.rule).frame(height: 1) }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

/// One day's evaluated hours and reasons, as the "Day detail" board draws it.
struct DayDetailView: View {
    @Environment(ForecastController.self) private var forecast
    let day: Date

    var body: some View {
        ScrollView {
            if let detail = forecast.detail(for: day) {
                VStack(alignment: .leading, spacing: 16) {
                    Text(detail.title.uppercased()).font(Theme.display(.subheadline, weight: .semibold)).tracking(3)
                        .foregroundStyle(Theme.inkSecondary)
                    HStack(alignment: .firstTextBaseline, spacing: 0) {
                        Text(detail.word)
                        Text(".").foregroundStyle(Theme.accent)
                    }
                    .font(.system(size: 110, weight: .black).width(.compressed))
                    .foregroundStyle(detail.verdict == .nah ? Theme.nahInk : Theme.accent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.3)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(detail.verdict.map(VerdictWords.spoken) ?? "Done")
                    .accessibilityIdentifier("detail.word")
                    Text(detail.summary).font(Theme.reason()).foregroundStyle(Theme.reasonWarm)
                    hoursCard(detail)
                    if !detail.reasons.isEmpty {
                        ReasonsCard(title: "Why \(detail.word.lowercased())", reasons: detail.reasons)
                    }
                    WeatherAttributionView(info: forecast.attribution).frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
        .background(Theme.ground)
        .navigationTitle("Next 7 days")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("detail.screen")
    }

    func hoursCard(_ detail: DayDetailContent) -> some View {
        Card {
            HStack {
                SectionLabel(text: "Evaluated hours")
                Spacer()
                Text(detail.hoursCaption).font(.footnote).foregroundStyle(Theme.inkTertiary)
            }
            Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 8) {
                GridRow {
                    ForEach(["Hour", "Temp", "Feels", "Rain", "Wind/gust", "UV"], id: \.self) { title in
                        Text(title.uppercased()).font(.caption2.weight(.semibold)).foregroundStyle(Theme.inkQuiet)
                    }
                }
                ForEach(Array(detail.sections.enumerated()), id: \.offset) { _, section in
                    GridRow {
                        HStack(spacing: 8) {
                            Text(section.title).font(Theme.display(.headline, weight: .bold))
                            VerdictPill(verdict: section.verdict)
                        }
                        .gridCellColumns(6)
                    }
                    ForEach(Array(section.hours.enumerated()), id: \.offset) { _, hour in
                        GridRow {
                            Text(hour.hour).foregroundStyle(Theme.inkSecondary)
                            Text(hour.temperature)
                            Text(hour.feelsLike)
                            Text(hour.rainChance)
                            Text(hour.windAndGusts)
                            Text(hour.uv).accessibilityLabel(hour.uv == "—" ? "unavailable" : hour.uv)
                        }
                        .font(.subheadline)
                        .foregroundStyle(Theme.ink)
                        ForEach(Array(hour.marks.enumerated()), id: \.offset) { _, mark in
                            GridRow {
                                HStack(spacing: 8) {
                                    SeverityTag(severity: mark.severity)
                                    Text(mark.text).font(.caption).foregroundStyle(Theme.reasonWarm)
                                }
                                .gridCellColumns(6)
                            }
                            .accessibilityIdentifier("detail.mark")
                        }
                    }
                }
            }
        }
    }
}
