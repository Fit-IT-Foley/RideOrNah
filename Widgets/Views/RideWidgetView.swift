import Presentation
import SwiftUI
import VerdictEngine
import WidgetKit

/// Every widget family, in the design-system style. Compiled into the app as well as the
/// extension, so app-hosted tests can render it.
struct RideWidgetView: View {
    @Environment(\.widgetFamily) private var environmentFamily
    let content: WidgetContent
    /// Previews and tests pick a family; widgets use the one they're placed as.
    var family: WidgetFamily?

    var body: some View {
        Group {
            switch family ?? environmentFamily {
            case .systemMedium: medium
            case .accessoryCircular: circular
            case .accessoryRectangular: rectangular
            case .accessoryInline: inline
            default: small
            }
        }
        .widgetURL(content.url)
        .containerBackground(Theme.ground, for: .widget)
    }

    var small: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(content.label.uppercased()).font(Theme.display(.caption, weight: .semibold)).tracking(2)
                    .foregroundStyle(Theme.inkSecondary)
                if let place = content.place {
                    Text(place).font(.caption2).foregroundStyle(Theme.inkTertiary).lineLimit(1).privacySensitive()
                }
            }
            Spacer(minLength: 0)
            if let word = content.word, let verdict = content.verdict {
                Text("\(word)\(Text(".").foregroundStyle(dotColor(verdict)))")
                    .font(.system(size: 44, weight: .black).width(.compressed))
                    .foregroundStyle(wordColor(verdict))
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .accessibilityLabel(VerdictPill.spoken(verdict))
            } else if content.state == .locked {
                Image(systemName: "lock.fill").font(.title2).foregroundStyle(Theme.accent)
            }
            Text(content.reason).font(.caption).foregroundStyle(Theme.ink).lineLimit(content.word == nil ? 3 : 2)
            if let age = content.age {
                Text(age).font(.caption2).foregroundStyle(content.isStale ? Theme.reasonWarm : Theme.inkTertiary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    var medium: some View {
        HStack(spacing: 14) {
            small
            if !content.days.isEmpty {
                VStack(spacing: 6) {
                    ForEach(content.days, id: \.day) { day in
                        Link(destination: day.url) {
                            HStack(spacing: 8) {
                                Text(day.weekday).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
                                    .frame(width: 36, alignment: .leading)
                                if let verdict = day.verdict {
                                    VerdictPill(verdict: verdict).scaleEffect(0.85, anchor: .leading)
                                } else {
                                    Text(day.word).foregroundStyle(Theme.inkQuiet)
                                }
                                Spacer(minLength: 0)
                                if day.lowerConfidence {
                                    Image(systemName: "questionmark.circle").font(.caption).foregroundStyle(
                                        Theme.inkTertiary
                                    )
                                    .accessibilityLabel("Lower confidence")
                                }
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    var circular: some View {
        ZStack {
            AccessoryWidgetBackground()
            if let word = content.word {
                Text(word).font(.system(size: 13, weight: .black).width(.compressed)).minimumScaleFactor(0.6)
            } else {
                Image(systemName: content.state == .locked ? "lock.fill" : "questionmark")
            }
        }
        .accessibilityLabel(content.verdict.map(VerdictPill.spoken) ?? content.reason)
    }

    var rectangular: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(content.word.map { "\(content.label): \($0)" } ?? "Ride or Nah").font(.headline).widgetAccentable()
            Text(content.reason).font(.caption).lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    var inline: some View {
        Text(content.word.map { "\($0) · \(content.reason)" } ?? content.reason)
    }

    func wordColor(_ verdict: Verdict) -> Color {
        switch verdict {
        case .ride: Theme.accent
        case .nah: Theme.nahInk
        case .maybe, .unknown: Theme.ink
        }
    }

    func dotColor(_ verdict: Verdict) -> Color { verdict == .nah ? Theme.nah : Theme.accent }
}
