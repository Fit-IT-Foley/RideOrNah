import Foundation
import VerdictEngine

/// A value the rider can set, for validation and display.
public enum LimitField: String, Sendable, CaseIterable {
    case precipitationChance, precipitationIntensity, cold, heat, humidity, wind, gusts, uv, visibility
    case wetRoadsDuration, iceThreshold, minimumRideDuration

    /// The allowed SI range.
    public var range: ClosedRange<Double> {
        switch self {
        case .precipitationChance, .humidity: 0...1
        case .precipitationIntensity: 0...50
        case .cold, .heat, .iceThreshold: -40...60
        case .wind, .gusts: 0...60
        case .uv: 0...15
        case .visibility: 0...20_000
        case .wetRoadsDuration: 0...(12 * 3600)
        case .minimumRideDuration: (30 * 60)...(8 * 3600)
        }
    }

    /// True for limits where a lower value is worse.
    public var lowerIsWorse: Bool { self == .cold || self == .visibility }

    public var title: String {
        switch self {
        case .precipitationChance: "Rain chance"
        case .precipitationIntensity: "Rain intensity"
        case .cold: "Cold"
        case .heat: "Heat (feels like)"
        case .humidity: "Humidity"
        case .wind: "Wind"
        case .gusts: "Gusts"
        case .uv: "UV index"
        case .visibility: "Visibility"
        case .wetRoadsDuration: "Wet roads after rain"
        case .iceThreshold: "Ice risk at or below"
        case .minimumRideDuration: "Shortest ride worth suggesting"
        }
    }
}

public struct ValidationError: Error, Sendable, Equatable {
    public var field: LimitField?
    public var message: String
}

public enum LimitValidator {
    /// Every problem with a profile's limits and durations, empty when it's valid.
    public static func problems(in profile: RiderProfile) -> [ValidationError] {
        let limits = profile.limits
        var problems: [ValidationError] = []
        func check(_ field: LimitField, _ limit: ThresholdLimit) {
            for value in [limit.soft, limit.hard].compactMap({ $0 }) where !field.range.contains(value) {
                problems.append(ValidationError(field: field, message: "\(field.title) is outside the possible range."))
            }
            guard let soft = limit.soft, let hard = limit.hard else { return }
            if field.lowerIsWorse ? soft < hard : soft > hard {
                problems.append(
                    ValidationError(
                        field: field,
                        message: field.lowerIsWorse
                            ? "The soft limit must be higher than the hard limit."
                            : "The soft limit must be lower than the hard limit."))
            }
        }
        check(.precipitationChance, limits.precipitation.chance)
        check(.precipitationIntensity, limits.precipitation.intensity)
        check(.cold, limits.cold)
        check(.heat, limits.heat)
        check(.humidity, limits.humidity)
        check(.wind, limits.wind)
        check(.gusts, limits.gusts)
        check(.uv, limits.uv)
        check(.visibility, limits.visibility)
        for (field, value) in [
            (LimitField.wetRoadsDuration, limits.wetRoads.duration), (.iceThreshold, limits.ice.threshold),
            (.minimumRideDuration, profile.minimumRideDuration),
        ] where !field.range.contains(value) {
            problems.append(ValidationError(field: field, message: "\(field.title) is outside the allowed range."))
        }
        return problems
    }
}

public enum WindowValidator {
    public static let maximumPerDay = 4

    /// Every problem with a set of ride windows, empty when they're valid.
    public static func problems(in windows: [RideWindow]) -> [ValidationError] {
        var problems: [ValidationError] = []
        if windows.contains(where: { $0.end <= $0.start || $0.start < 0 || $0.end > 24 * 60 }) {
            problems.append(
                ValidationError(field: nil, message: "A ride window must end after it starts, on the same day."))
        }
        for weekday in 1...7 {
            let day = windows.filter { $0.weekdays.contains(weekday) }.sorted { $0.start < $1.start }
            if day.count > maximumPerDay {
                problems.append(
                    ValidationError(field: nil, message: "A day can have at most \(maximumPerDay) ride windows."))
            }
            for (earlier, later) in zip(day, day.dropFirst()) where later.start < earlier.end {
                problems.append(
                    ValidationError(field: nil, message: "These ride windows overlap. Pick times that don't."))
            }
        }
        return problems
    }
}
