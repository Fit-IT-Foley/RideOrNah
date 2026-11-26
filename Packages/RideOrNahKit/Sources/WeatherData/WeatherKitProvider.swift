import CoreLocation
import Foundation
import VerdictEngine
import WeatherKit

/// Pure mappings from WeatherKit's types, testable without the service.
public enum ConditionMapper {
    /// Exhaustive on purpose: a new WeatherKit condition stops the build until it's mapped.
    public static func hazards(for condition: WeatherCondition) -> HazardFlags {
        switch condition {
        case .isolatedThunderstorms, .scatteredThunderstorms, .strongStorms, .thunderstorms, .tropicalStorm,
            .hurricane:
            .thunderstorm
        case .hail:
            .hail
        case .blizzard, .blowingSnow, .flurries, .freezingDrizzle, .freezingRain, .heavySnow, .sleet, .snow,
            .sunFlurries, .wintryMix:
            .frozenPrecipitation
        case .foggy:
            .fog
        case .blowingDust, .breezy, .clear, .cloudy, .drizzle, .frigid, .haze, .heavyRain, .hot, .mostlyClear,
            .mostlyCloudy, .partlyCloudy, .rain, .smoky, .sunShowers, .windy:
            []
        @unknown default:
            []
        }
    }

    /// WeatherKit's `unknown` severity counts as moderate, so an unclassified alert still makes
    /// the day a Maybe rather than being ignored.
    public static func severity(_ severity: WeatherSeverity) -> AlertSeverity {
        switch severity {
        case .minor: .minor
        case .moderate, .unknown: .moderate
        case .severe: .severe
        case .extreme: .extreme
        @unknown default: .moderate
        }
    }

    public static func conditions(_ hour: HourWeather) -> HourConditions {
        HourConditions(
            start: hour.date,
            temperature: hour.temperature.converted(to: .celsius).value,
            feelsLike: hour.apparentTemperature.converted(to: .celsius).value,
            humidity: hour.humidity,
            windSpeed: hour.wind.speed.converted(to: .metersPerSecond).value,
            windGust: hour.wind.gust?.converted(to: .metersPerSecond).value,
            uvIndex: Double(hour.uvIndex.value),
            visibility: hour.visibility.converted(to: .meters).value,
            precipitationChance: hour.precipitationChance,
            precipitationIntensity: hour.precipitationAmount.converted(to: .millimeters).value,
            hazards: hazards(for: hour.condition))
    }

    /// WeatherKit alerts carry no active period, so they apply to the current day.
    public static func alert(_ alert: WeatherAlert) -> PointAlert {
        PointAlert(name: alert.summary, severity: severity(alert.severity))
    }

    public static func sourceError(_ error: any Error) -> WeatherSourceError {
        if let error = error as? WeatherError, case .permissionDenied = error { return .notAuthorized }
        if let error = error as? URLError,
            [.notConnectedToInternet, .networkConnectionLost, .dataNotAllowed, .internationalRoamingOff].contains(
                error.code)
        {
            return .offline
        }
        return .serviceUnavailable
    }
}

/// Live forecasts from WeatherKit: one request per point, with hourly, daily and alert data.
public struct WeatherKitProvider: WeatherProviding {
    public init() {}

    public var makesNetworkRequests: Bool { true }

    public func forecast(at coordinate: RoundedCoordinate, hours: DateInterval, days: DateInterval)
        async throws(WeatherSourceError) -> PointForecast
    {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        do {
            let (hourly, daily, alerts) = try await WeatherService.shared.weather(
                for: location,
                including: .hourly(startDate: hours.start, endDate: hours.end),
                .daily(startDate: days.start, endDate: days.end), .alerts)
            return PointForecast(
                hours: hourly.forecast.map(ConditionMapper.conditions),
                days: daily.forecast.map { DaySun(day: $0.date, sunrise: $0.sun.sunrise, sunset: $0.sun.sunset) },
                alerts: alerts?.map(ConditionMapper.alert))
        } catch {
            throw ConditionMapper.sourceError(error)
        }
    }
}

/// What the app needs to attribute Apple Weather: the combined mark for each appearance and the
/// legal attribution page.
public struct WeatherAttributionInfo: Sendable, Equatable {
    public var lightMarkURL: URL?
    public var darkMarkURL: URL?
    public var legalPageURL: URL

    public init(lightMarkURL: URL?, darkMarkURL: URL?, legalPageURL: URL) {
        self.lightMarkURL = lightMarkURL
        self.darkMarkURL = darkMarkURL
        self.legalPageURL = legalPageURL
    }

    /// Apple's legal page, for fixture builds that can't ask WeatherKit.
    public static let fixture = WeatherAttributionInfo(
        lightMarkURL: nil, darkMarkURL: nil,
        legalPageURL: URL(string: "https://weatherkit.apple.com/legal-attribution.html")!)

    /// Asks WeatherKit once.
    public static func live() async throws -> WeatherAttributionInfo {
        let attribution = try await WeatherService.shared.attribution
        return WeatherAttributionInfo(
            lightMarkURL: attribution.combinedMarkLightURL, darkMarkURL: attribution.combinedMarkDarkURL,
            legalPageURL: attribution.legalPageURL)
    }
}
