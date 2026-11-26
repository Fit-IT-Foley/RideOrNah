import SwiftUI
import VerdictEngine

/// Tokens and components from the design canvas (see docs/design-system.md). Screens use these
/// and never hard-code colors or fonts.
enum Theme {
    static let ground = Color(hex: 0x0A0B0D)
    static let ink = Color(hex: 0xF2F1EE)
    static let inkSecondary = Color(hex: 0xC9CCD2)
    static let inkTertiary = Color(hex: 0x9A9EA6)
    static let inkQuiet = Color(hex: 0x8A8E96)
    static let accent = Color(hex: 0xFF6B1A)
    static let nah = Color(hex: 0xBFD8EE)
    static let nahInk = Color(hex: 0xE8EEF5)
    static let reasonWarm = Color(hex: 0xFFE2C7)
    static let card = Color.white.opacity(0.05)
    static let cardEdge = Color.white.opacity(0.09)
    static let rule = Color.white.opacity(0.1)

    /// Condensed, heavy display type for headings and pills.
    static func display(_ style: Font.TextStyle, weight: Font.Weight = .heavy) -> Font {
        .system(style, weight: weight).width(.condensed)
    }

    /// The italic serif reason line.
    static func reason(_ style: Font.TextStyle = .title2) -> Font {
        .system(style, design: .serif, weight: .semibold).italic()
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255)
    }
}

/// "RIDE or NAH": condensed caps with an italic serif "or" in the accent.
struct Wordmark: View {
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            Text("RIDE")
            Text("or").font(Theme.reason(.headline)).foregroundStyle(Theme.accent)
            Text("NAH")
        }
        .font(Theme.display(.title3))
        .foregroundStyle(Theme.ink)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Ride or Nah")
    }
}

/// Condensed, tracked uppercase label above a section.
struct SectionLabel: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(Theme.display(.subheadline, weight: .semibold))
            .tracking(3)
            .foregroundStyle(Theme.inkSecondary)
            .accessibilityAddTraits(.isHeader)
    }
}

/// A rounded panel on the ground.
struct Card<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 12) { content }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: .rect(cornerRadius: 26))
            .overlay(RoundedRectangle(cornerRadius: 26).strokeBorder(Theme.cardEdge))
    }
}

/// Ride is a filled accent pill, Maybe an accent outline, Nah a filled pale blue, Unknown a
/// dashed outline. Always labelled in words.
struct VerdictPill: View {
    let verdict: Verdict
    var body: some View {
        Text(Self.word(verdict))
            .font(Theme.display(.subheadline, weight: .bold))
            .tracking(1)
            .padding(.horizontal, 12)
            .frame(minHeight: 26)
            .foregroundStyle(verdict == .maybe ? Theme.ink : verdict == .unknown ? Theme.inkQuiet : Theme.ground)
            .background(fill, in: .capsule)
            .overlay {
                switch verdict {
                case .maybe: Capsule().strokeBorder(Theme.accent, lineWidth: 1.5)
                case .unknown: Capsule().strokeBorder(Theme.inkQuiet, style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                default: EmptyView()
                }
            }
            .accessibilityLabel(Self.spoken(verdict))
    }

    var fill: Color {
        switch verdict {
        case .ride: Theme.accent
        case .nah: Theme.nah
        case .maybe, .unknown: .clear
        }
    }

    static func word(_ verdict: Verdict) -> String {
        switch verdict {
        case .ride: "RIDE"
        case .maybe: "MAYBE"
        case .nah: "NAH"
        case .unknown: "CAN'T TELL"
        }
    }

    static func spoken(_ verdict: Verdict) -> String {
        switch verdict {
        case .ride: "Ride"
        case .maybe: "Maybe"
        case .nah: "Nah"
        case .unknown: "Can't tell"
        }
    }
}

/// A capsule button for profile, location and radius on dark glass.
struct Chip: View {
    let systemImage: String
    let title: String
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemImage).imageScale(.small)
                Text(title).font(.subheadline.weight(.semibold))
                Image(systemName: "chevron.down").imageScale(.small).foregroundStyle(Theme.inkQuiet)
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 36)
            .foregroundStyle(Theme.ink)
            .adaptiveSurface(in: .capsule)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}

/// The main call to action: an accent capsule with dark text, at least 44 pt tall.
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(Theme.ground)
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(Theme.accent.opacity(configuration.isPressed ? 0.8 : 1), in: .capsule)
    }
}

/// A secondary action: an outlined capsule.
struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity, minHeight: 50)
            .overlay(Capsule().strokeBorder(Color.white.opacity(configuration.isPressed ? 0.35 : 0.18)))
    }
}
