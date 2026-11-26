import Foundation

/// The kinds of values shown to riders, each stored in SI and displayed in their units.
public enum Quantity: Sendable {
    /// °C stored; °F or °C shown.
    case temperature
    /// m/s stored; mph or km/h shown.
    case speed
    /// Metres stored; miles or kilometres shown.
    case distance
    /// mm/h stored; in/h or mm/h shown.
    case precipitationRate
    /// A fraction stored; a percentage shown.
    case percentage
    /// Shown as stored.
    case index

    public func display(_ si: Double, in units: UnitSystem) -> Double {
        switch (self, units) {
        case (.temperature, .imperial): si * 9 / 5 + 32
        case (.speed, .imperial): si / 0.44704
        case (.speed, .metric): si * 3.6
        case (.distance, .imperial): si / 1609.344
        case (.distance, .metric): si / 1000
        case (.precipitationRate, .imperial): si / 25.4
        case (.percentage, _): si * 100
        default: si
        }
    }

    public func si(fromDisplay value: Double, in units: UnitSystem) -> Double {
        switch (self, units) {
        case (.temperature, .imperial): (value - 32) * 5 / 9
        case (.speed, .imperial): value * 0.44704
        case (.speed, .metric): value / 3.6
        case (.distance, .imperial): value * 1609.344
        case (.distance, .metric): value * 1000
        case (.precipitationRate, .imperial): value * 25.4
        case (.percentage, _): value / 100
        default: value
        }
    }

    public func symbol(in units: UnitSystem) -> String {
        switch (self, units) {
        case (.temperature, .imperial): "°F"
        case (.temperature, .metric): "°C"
        case (.speed, .imperial): "mph"
        case (.speed, .metric): "km/h"
        case (.distance, .imperial): "mi"
        case (.distance, .metric): "km"
        case (.precipitationRate, .imperial): "in/h"
        case (.precipitationRate, .metric): "mm/h"
        case (.percentage, _): "%"
        case (.index, _): ""
        }
    }
}

extension LimitField {
    public var quantity: Quantity? {
        switch self {
        case .precipitationChance, .humidity: .percentage
        case .precipitationIntensity: .precipitationRate
        case .cold, .heat, .iceThreshold: .temperature
        case .wind, .gusts: .speed
        case .uv: .index
        case .visibility: .distance
        case .wetRoadsDuration, .minimumRideDuration: nil
        }
    }
}
