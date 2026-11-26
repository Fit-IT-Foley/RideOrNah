#if DEBUG
    import Foundation
    import VerdictEngine

    /// Canned weather for debug builds, previews and tests. Makes no network requests; release
    /// builds don't contain it.
    public struct FixtureProvider: WeatherProviding {
        public enum Scenario: String, Sendable, CaseIterable {
            case clearDay
            case afternoonRain
            case stormToTheNorth
            case freezingMorning
            case gusty
        }

        public let scenario: Scenario
        /// The evaluation location, so the storm scenario knows which points are to the north.
        public let center: GeoCoordinate
        public let calendar: Calendar

        public init(scenario: Scenario, center: GeoCoordinate, calendar: Calendar) {
            self.scenario = scenario
            self.center = center
            self.calendar = calendar
        }

        public var makesNetworkRequests: Bool { false }

        public func forecast(at coordinate: RoundedCoordinate, hours: DateInterval, days: DateInterval)
            async throws(WeatherSourceError) -> PointForecast
        {
            var starts: [Date] = []
            var hour = hours.start
            while hour < hours.end {
                starts.append(hour)
                hour = hour.addingTimeInterval(3600)
            }
            var dayStarts: [Date] = []
            var day = calendar.startOfDay(for: days.start)
            while day < days.end {
                dayStarts.append(day)
                day = calendar.date(byAdding: .day, value: 1, to: day)!
            }
            let north = isNorth(coordinate)
            return PointForecast(
                hours: starts.map { conditions(at: $0, north: north) },
                days: dayStarts.map { day in
                    DaySun(
                        day: day,
                        sunrise: calendar.date(bySettingHour: 6, minute: 30, second: 0, of: day),
                        sunset: calendar.date(bySettingHour: 19, minute: 30, second: 0, of: day))
                },
                alerts: [])
        }

        func conditions(at start: Date, north: Bool) -> HourConditions {
            var hour = HourConditions(
                start: start, temperature: 21, feelsLike: 21, humidity: 0.5, windSpeed: 3, windGust: 5, uvIndex: 4,
                visibility: 16_000, precipitationChance: 0.05, precipitationIntensity: 0)
            let localHour = calendar.component(.hour, from: start)
            switch scenario {
            case .clearDay:
                break
            case .afternoonRain:
                if (13..<18).contains(localHour) {
                    hour.precipitationChance = 0.8
                    hour.precipitationIntensity = 2
                }
            case .stormToTheNorth:
                if north {
                    hour.precipitationChance = 0.9
                    hour.precipitationIntensity = 6
                    hour.hazards = .thunderstorm
                }
            case .freezingMorning:
                if (4..<11).contains(localHour) {
                    hour.temperature = -1
                    hour.feelsLike = -4
                    hour.humidity = 0.97
                }
            case .gusty:
                hour.windSpeed = 10
                hour.windGust = 20
            }
            return hour
        }

        /// N, NE and NW points: well north of the center and within 67.5° of due north.
        func isNorth(_ coordinate: RoundedCoordinate) -> Bool {
            let dLat = coordinate.latitude - center.latitude
            let dLon = (coordinate.longitude - center.longitude) * cos(center.latitude * .pi / 180)
            guard dLat > 0.02 else { return false }
            return abs(atan2(dLon, dLat) * 180 / .pi) <= 67.5
        }
    }
#endif
