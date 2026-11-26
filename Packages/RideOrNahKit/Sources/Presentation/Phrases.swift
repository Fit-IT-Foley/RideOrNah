import Foundation
import VerdictEngine

/// How each breach is put into words.
extension DisplayFormatter {
    /// The one-line summary for a day's most severe breach: factor, worst value, time range.
    public func summary(_ breach: Breach) -> String {
        summary(breach, when: timeRange(breach.range))
    }

    /// The summary with its time put another way, such as `from 3 PM`.
    public func summary(_ breach: Breach, when range: String) -> String {
        let worst = breach.worstValue.map { value($0, for: breach.factor) } ?? ""
        switch breach.factor {
        case .precipitationChance: return "Rain likely \(range) (\(worst))"
        case .precipitationIntensity: return "Heavy rain \(range) (\(worst))"
        case .storm: return "Thunderstorms \(range)"
        case .cold: return "Cold: \(worst), \(range)"
        case .heat: return "Heat: feels like \(worst), \(range)"
        case .humidity: return "Humid: \(worst), \(range)"
        case .wind: return "Wind \(worst), \(range)"
        case .gusts: return "Gusts up to \(worst), \(range)"
        case .uv: return "UV \(worst), \(range)"
        case .wetRoads: return "Wet roads \(range)"
        case .ice: return "Ice risk \(range)"
        case .visibility: return "Visibility down to \(worst), \(range)"
        case .fog: return "Fog \(range)"
        case .alert: return breach.alertName ?? "Weather alert"
        }
    }

    /// A reason row's title, such as `Gusts up to 34 mph`.
    public func reasonTitle(_ breach: Breach) -> String {
        let worst = breach.worstValue.map { value($0, for: breach.factor) } ?? ""
        switch breach.factor {
        case .precipitationChance: return "Rain chance up to \(worst)"
        case .precipitationIntensity: return "Rain up to \(worst)"
        case .storm: return "Thunderstorms or hail"
        case .cold: return "Cold down to \(worst)"
        case .heat: return "Feels like up to \(worst)"
        case .humidity: return "Humidity up to \(worst)"
        case .wind: return "Wind up to \(worst)"
        case .gusts: return "Gusts up to \(worst)"
        case .uv: return "UV index up to \(worst)"
        case .wetRoads: return "Wet roads after rain"
        case .ice: return "Ice risk"
        case .visibility: return "Visibility down to \(worst)"
        case .fog: return "Fog"
        case .alert: return breach.alertName ?? "Weather alert"
        }
    }

    /// `(your limit 30 mph)`, or nil for breaches without a numeric limit.
    public func reasonLimit(_ breach: Breach) -> String? {
        guard let limit = breach.limit, breach.factor != .ice else { return nil }
        return "(your limit \(value(limit, for: breach.factor)))"
    }

    /// `4–7 PM · to the west`.
    public func reasonDetail(_ breach: Breach) -> String {
        "\(timeRange(breach.range)) · \(places(breach.positions))"
    }

    /// The short note on a ride-window row, such as `Rain 80%, here and to the N`.
    public func windowNote(_ breach: Breach) -> String {
        let worst = breach.worstValue.map { value($0, for: breach.factor) }
        let what: String =
            switch breach.factor {
            case .precipitationChance, .precipitationIntensity: "Rain \(worst ?? "")"
            case .gusts: "Gusts to \(worst ?? "")"
            case .wind: "Wind \(worst ?? "")"
            case .cold: "Cold \(worst ?? "")"
            case .heat: "Feels like \(worst ?? "")"
            default: reasonTitle(breach)
            }
        return "\(what.trimmingCharacters(in: .whitespaces)), \(places(breach.positions))"
    }

    /// A factor's name for marks and room-to-limits rows.
    public func factorName(_ factor: Factor) -> String {
        switch factor {
        case .precipitationChance: "Rain chance"
        case .precipitationIntensity: "Rain"
        case .storm: "Storms"
        case .cold: "Cold"
        case .heat: "Heat"
        case .humidity: "Humidity"
        case .wind: "Wind"
        case .gusts: "Gusts"
        case .uv: "UV"
        case .wetRoads: "Wet roads"
        case .ice: "Ice"
        case .visibility: "Visibility"
        case .fog: "Fog"
        case .alert: "Alert"
        }
    }
}
