import Presentation
import SwiftUI
import VerdictEngine
import WeatherData
import WidgetKit

/// The watch app's one screen: today's call, its windows and reasons, the next six days, and
/// the Apple Weather mark. Plain SwiftUI, so it also builds into the iPhone app for tests.
struct WatchMainView: View {
    let content: WatchContent
    var markURL: URL?
    var legalURL: URL?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text(content.label.uppercased()).font(Theme.display(.caption2, weight: .semibold)).tracking(2)
                    .foregroundStyle(Theme.inkSecondary)
                if let word = content.word, let verdict = content.verdict {
                    Text("\(word)\(Text(".").foregroundStyle(verdict == .nah ? Theme.nah : Theme.accent))")
                        .font(.system(size: 44, weight: .black).width(.compressed))
                        .foregroundStyle(verdict == .ride ? Theme.accent : verdict == .nah ? Theme.nahInk : Theme.ink)
                        .accessibilityLabel(VerdictWords.spoken(verdict))
                        .accessibilityIdentifier("watch.word")
                } else if content.state == .locked {
                    Image(systemName: "lock.fill").font(.title3).foregroundStyle(Theme.accent)
                }
                Text(content.reason).font(.footnote).foregroundStyle(Theme.ink)
                    .accessibilityIdentifier("watch.reason")
                if let age = content.age {
                    Text(content.isStale ? "\(age) · older forecast" : age).font(.caption2)
                        .foregroundStyle(content.isStale ? Theme.reasonWarm : Theme.inkTertiary)
                }
                ForEach(content.windows, id: \.text) { window in
                    HStack {
                        Text(window.text).font(.footnote)
                        Spacer(minLength: 0)
                        VerdictPill(verdict: window.verdict).scaleEffect(0.75, anchor: .trailing)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("watch.window")
                }
                ForEach(content.reasons.filter { $0 != content.reason }, id: \.self) { reason in
                    Text(reason).font(.caption2).foregroundStyle(Theme.reasonWarm)
                }
                if let directions = content.directionText {
                    Text(directions).font(.caption2).foregroundStyle(Theme.inkSecondary)
                }
                if let profile = content.profileName, let place = content.placeName {
                    Text("\(profile) · \(place)").font(.caption2).foregroundStyle(Theme.inkTertiary)
                }
                ForEach(content.days, id: \.day) { day in
                    HStack {
                        Text(day.weekday).font(.footnote)
                        Spacer(minLength: 0)
                        if day.lowerConfidence {
                            Image(systemName: "questionmark.circle").font(.caption2).foregroundStyle(Theme.inkTertiary)
                                .accessibilityLabel("Lower confidence")
                        }
                        if let verdict = day.verdict {
                            VerdictPill(verdict: verdict).scaleEffect(0.75, anchor: .trailing)
                        }
                    }
                }
                if content.state == .verdict || content.state == .unknown {
                    WeatherAttributionView(
                        info: WeatherAttributionInfo(
                            lightMarkURL: nil, darkMarkURL: markURL,
                            legalPageURL: legalURL ?? WeatherAttributionInfo.fixture.legalPageURL)
                    )
                    .padding(.top, 6)
                }
            }
            .padding(.horizontal, 4)
        }
        .background(Theme.ground)
        .accessibilityIdentifier("watch.screen")
    }
}

/// The watch-face complications. Place names hide while the wrist is down or the watch is locked.
struct WatchComplicationView: View {
    @Environment(\.widgetFamily) private var environmentFamily
    let content: WatchContent
    /// Previews and tests pick a family; complications use the one they're placed as.
    var family: WidgetFamily?

    var body: some View {
        switch family ?? environmentFamily {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                if let word = content.word {
                    Text(word).font(.system(size: 12, weight: .black).width(.compressed)).minimumScaleFactor(0.6)
                } else {
                    Image(systemName: content.state == .locked ? "lock.fill" : "iphone")
                }
            }
        case .accessoryInline:
            Text(content.verdict.map { "\(VerdictWords.spoken($0)) · \(content.reason)" } ?? content.reason)
        #if os(watchOS)
            case .accessoryCorner:
                Text(content.word ?? "–").font(.system(size: 14, weight: .black).width(.compressed))
                    .widgetLabel { Text(content.reason) }
        #endif
        default:
            VStack(alignment: .leading, spacing: 1) {
                Text(content.verdict.map { "\(content.label): \(VerdictWords.spoken($0))" } ?? "Ride or Nah")
                    .font(.headline).widgetAccentable()
                Text(content.reason).font(.caption2).lineLimit(2)
                if let place = content.placeName {
                    Text(place).font(.caption2).foregroundStyle(.secondary).privacySensitive()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
