import Foundation

/// The answer for a day, a ride window or a time range.
public enum Verdict: String, Sendable, Codable, CaseIterable {
    /// No limit breached.
    case ride
    /// At least one soft limit breached, and no hard limit.
    case maybe
    /// At least one hard limit breached.
    case nah
    /// Not enough fresh data to decide. Never shown as Ride.
    case unknown

    /// Ride < Maybe < Nah. Unknown has no rank.
    public var rank: Int? {
        switch self {
        case .ride: 0
        case .maybe: 1
        case .nah: 2
        case .unknown: nil
        }
    }

    /// Combines verdicts the way a day combines its windows: a known Nah outranks everything,
    /// Unknown outranks Ride and Maybe, and otherwise the most severe wins. No verdicts is Ride.
    public static func combining(_ verdicts: some Sequence<Verdict>) -> Verdict {
        var worst = Verdict.ride
        var sawUnknown = false
        for verdict in verdicts {
            if verdict == .nah { return .nah }
            if verdict == .unknown {
                sawUnknown = true
            } else if let rank = verdict.rank, rank > (worst.rank ?? 0) {
                worst = verdict
            }
        }
        return sawUnknown ? .unknown : worst
    }
}

/// How bad a breach is. Soft limits make Maybe, hard limits make Nah.
public enum Severity: Int, Sendable, Codable, CaseIterable, Comparable {
    case soft = 1
    case hard = 2

    public static func < (lhs: Severity, rhs: Severity) -> Bool { lhs.rawValue < rhs.rawValue }

    public var verdict: Verdict { self == .hard ? .nah : .maybe }
}

/// What a breach is about. Several factors can belong to one rider-facing limit: precipitation
/// covers chance, intensity and storms, and visibility covers fog.
public enum Factor: String, Sendable, Codable, CaseIterable, Comparable {
    case precipitationChance
    case precipitationIntensity
    case storm
    case cold
    case heat
    case humidity
    case wind
    case gusts
    case uv
    case wetRoads
    case ice
    case visibility
    case fog
    case alert

    public enum Group: String, Sendable, Codable {
        case precipitation, cold, heat, humidity, wind, gusts, uv, wetRoads, ice, visibility, alerts
    }

    public var group: Group {
        switch self {
        case .precipitationChance, .precipitationIntensity, .storm: .precipitation
        case .cold: .cold
        case .heat: .heat
        case .humidity: .humidity
        case .wind: .wind
        case .gusts: .gusts
        case .uv: .uv
        case .wetRoads: .wetRoads
        case .ice: .ice
        case .visibility, .fog: .visibility
        case .alert: .alerts
        }
    }

    /// True when a lower value is worse, as for cold and visibility.
    var lowerIsWorse: Bool { self == .cold || self == .visibility }

    public static func < (lhs: Factor, rhs: Factor) -> Bool {
        allCases.firstIndex(of: lhs)! < allCases.firstIndex(of: rhs)!
    }
}
