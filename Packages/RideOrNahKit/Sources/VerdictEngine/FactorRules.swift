import Foundation

/// One breach in one hour at one sample point.
struct Finding: Sendable, Equatable {
    var factor: Factor
    var severity: Severity
    var value: Double?
    var limit: Double?
    var hour: Date
    var position: SamplePosition
    var alertName: String?
}

/// The per-hour rules, one per factor. Each takes an hour's conditions at one sample point.
struct FactorRules {
    /// Precipitation at or above this, in mm/h, makes roads wet.
    static let measurablePrecipitation = 0.1
    /// Relative humidity at or above this counts as damp for ice.
    static let iceHumidity = 0.95

    let limits: Limits

    struct Result {
        var findings: [Finding] = []
        var notChecked: Set<Factor> = []
        var partiallyChecked: Set<Factor> = []
    }

    /// Breaches for `hour`. `lookup` returns the same point's conditions for another hour start,
    /// for the wet-roads lookback.
    func evaluate(_ hour: HourConditions, at position: SamplePosition, lookup: (Date) -> HourConditions?) -> Result {
        var result = Result()

        func record(_ factor: Factor, _ breach: (Severity, Double)?, value: Double?) {
            guard let (severity, limit) = breach else { return }
            result.findings.append(
                Finding(
                    factor: factor, severity: severity, value: value, limit: limit, hour: hour.start, position: position
                ))
        }

        func check(_ factor: Factor, _ value: Double?, _ limit: ThresholdLimit) {
            guard limit.isEnabled else { return }
            guard let value else {
                result.notChecked.insert(factor)
                return
            }
            record(factor, Self.breach(value, limit, lowerIsWorse: factor.lowerIsWorse), value: value)
        }

        if limits.precipitation.isEnabled {
            check(.precipitationChance, hour.precipitationChance, limits.precipitation.chance)
            check(.precipitationIntensity, hour.precipitationIntensity, limits.precipitation.intensity)
            if !hour.hazards.isDisjoint(with: [.thunderstorm, .hail]) {
                result.findings.append(
                    Finding(factor: .storm, severity: .hard, hour: hour.start, position: position))
            }
        }
        check(.cold, hour.temperature, limits.cold)
        check(.heat, hour.feelsLike, limits.heat)
        check(.humidity, hour.humidity, limits.humidity)
        check(.wind, hour.windSpeed, limits.wind)
        check(.gusts, hour.windGust, limits.gusts)
        check(.uv, hour.uvIndex, limits.uv)

        if limits.visibility.isEnabled {
            if let visibility = hour.visibility {
                record(.visibility, Self.breach(visibility, limits.visibility, lowerIsWorse: true), value: visibility)
            } else if hour.hazards.contains(.fog) {
                result.findings.append(Finding(factor: .fog, severity: .soft, hour: hour.start, position: position))
            } else {
                result.notChecked.insert(.visibility)
            }
        }

        let wet = wetRoads(at: hour.start, lookup: lookup)
        if limits.wetRoads.isEnabled {
            if wet.isWet {
                result.findings.append(
                    Finding(factor: .wetRoads, severity: limits.wetRoads.severity, hour: hour.start, position: position)
                )
            }
            if wet.isPartial { result.partiallyChecked.insert(.wetRoads) }
        }

        if limits.ice.isEnabled {
            let damp = wet.isWet || (hour.humidity ?? 0) >= Self.iceHumidity
            if hour.hazards.contains(.frozenPrecipitation) {
                result.findings.append(Finding(factor: .ice, severity: .hard, hour: hour.start, position: position))
            } else if let temperature = hour.temperature, temperature <= limits.ice.threshold, damp {
                result.findings.append(
                    Finding(
                        factor: .ice, severity: .hard, value: temperature, limit: limits.ice.threshold,
                        hour: hour.start, position: position))
            }
        }
        return result
    }

    /// The breached severity and its limit. Hard wins when both are crossed.
    static func breach(_ value: Double, _ limit: ThresholdLimit, lowerIsWorse: Bool) -> (Severity, Double)? {
        func crossed(_ bound: Double?) -> Double? {
            guard let bound else { return nil }
            return (lowerIsWorse ? value <= bound : value >= bound) ? bound : nil
        }
        if let hard = crossed(limit.hard) { return (.hard, hard) }
        if let soft = crossed(limit.soft) { return (.soft, soft) }
        return nil
    }

    /// Roads are wet in an hour that starts before the end of a measurably wet hour plus the
    /// wet-road duration. Missing lookback hours make the check partial.
    func wetRoads(at hourStart: Date, lookup: (Date) -> HourConditions?) -> (isWet: Bool, isPartial: Bool) {
        let duration = max(0, limits.wetRoads.duration)
        // Hours starting up to `duration` before this one can still leave it wet.
        let lookback = Int((duration / 3600).rounded(.up))
        var isPartial = false
        for back in 0...lookback {
            let candidate = hourStart.addingTimeInterval(-Double(back) * 3600)
            guard hourStart < candidate.addingTimeInterval(3600 + duration) else { continue }
            guard let intensity = lookup(candidate)?.precipitationIntensity else {
                isPartial = true
                continue
            }
            if intensity >= Self.measurablePrecipitation { return (true, isPartial) }
        }
        return (false, isPartial)
    }
}
