# Spec Delta

## Purpose

Defines how RideOrNah samples, fetches, caches and budgets weather forecasts across a rider's ride radius, how it attributes the data, and how it reports failures, so verdicts stay accurate and running costs stay predictable.

## ADDED Requirements

### Requirement: Sample point layout
The system SHALL choose sample points from the evaluation location and ride radius. A local radius SHALL use only the evaluation location. A radius under 80 km (49.7 mi) SHALL use the evaluation location plus one point in each of the eight compass directions (N, NE, E, SE, S, SW, W, NW) at the full radius. A radius of 80 km (49.7 mi) or more SHALL also add eight points at half the radius. The threshold is set in kilometers, so the 50 mi and 80 km radius presets both get the inner ring.

#### Scenario: Default radius
- **WHEN** the ride radius is 25 mi (40 km)
- **THEN** nine sample points are used: the evaluation location and eight points 25 mi (40 km) away in each compass direction

#### Scenario: Large radius
- **WHEN** the ride radius is 100 mi (160 km)
- **THEN** seventeen sample points are used: the evaluation location, eight at 50 mi (80 km), and eight at 100 mi (160 km)

#### Scenario: Local radius
- **WHEN** the ride radius is local
- **THEN** only the evaluation location is sampled

### Requirement: Coordinate precision
The system SHALL round every sample coordinate to 0.01° of latitude and longitude before sending it to the weather service or using it as a cache key.

#### Scenario: Rounded request
- **WHEN** the evaluation location is 40.712776, -74.005974
- **THEN** the center sample is requested as 40.71, -74.01

### Requirement: Forecast coverage
For each sample point, the system SHALL obtain: hourly conditions from 12 hours before the start of today through the end of the sixth day after today; sunrise and sunset for today and the next six days; and official weather alerts where the weather service offers them. Each hour SHALL include, where available, air temperature, feels-like temperature, relative humidity, sustained wind, gusts, UV index, visibility, precipitation chance, precipitation amount, and condition hazards (thunderstorm, hail, frozen precipitation, fog).

#### Scenario: Lookback for wet roads
- **WHEN** forecasts are fetched at 06:00
- **THEN** hourly data starts at 12:00 the previous day, so rain before the first ride window is known

#### Scenario: Alerts unsupported in the region
- **WHEN** the weather service offers no alerts for a sample point's region
- **THEN** that sample is marked "alerts unavailable", so the verdict can report alerts as not checked

### Requirement: Forecast reuse and refresh intervals
The system SHALL reuse a cached forecast for a sample point instead of requesting a new one when the cached forecast is younger than the refresh interval for the purpose of the request: 60 minutes while the app is in the foreground, 2 hours for background refreshes and widgets, and 15 minutes for a refresh the rider explicitly requests.

#### Scenario: Reopening the app
- **WHEN** the rider opens the app 40 minutes after the last fetch
- **THEN** cached forecasts are used and no weather request is made

#### Scenario: Pull to refresh too soon
- **WHEN** the rider requests a refresh 10 minutes after the last fetch
- **THEN** no request is made, and the rider is told the forecast is already up to date

#### Scenario: Widget refresh
- **WHEN** a widget needs data 90 minutes after the last fetch
- **THEN** cached forecasts are used and no weather request is made

### Requirement: Daily request budget
The system SHALL make at most 150 weather requests per device per local calendar day, counted across the app and all its extensions. When the budget is exhausted, it SHALL serve cached forecasts and report that refreshing is paused until tomorrow.

#### Scenario: Budget exhausted
- **WHEN** 150 requests have been made today and the cached forecast is 3 hours old
- **THEN** no request is made, the cached forecast is used, and the result is flagged budget-limited

#### Scenario: New day
- **WHEN** the local date changes
- **THEN** the budget resets to 150

### Requirement: Shared on-device cache
Forecasts fetched by the app or any of its iPhone extensions SHALL be reusable by all of them without another request.

#### Scenario: Widget after app refresh
- **WHEN** the app fetched forecasts 5 minutes ago and a widget then needs data for the same sample points
- **THEN** the widget uses those forecasts and makes no request

### Requirement: Data retention
The system SHALL delete cached forecasts more than 48 hours old. Cached forecasts SHALL be stored only on the device, in storage excluded from backups.

#### Scenario: Old cache entries
- **WHEN** a cached forecast was fetched 49 hours ago
- **THEN** it is deleted the next time the cache is accessed

### Requirement: Failure reporting
The system SHALL report the outcome of every forecast request set as one of: complete; partial (naming the sample points that failed); offline; weather service unavailable; not authorized to use the weather service; or budget-limited. In every non-complete case, it SHALL return the freshest cached forecasts available, with their age, or no forecast at all, and SHALL NEVER substitute invented or default weather values.

#### Scenario: Offline with cache
- **WHEN** the device is offline and a 4-hour-old forecast is cached
- **THEN** the cached forecast is returned with its age, and the outcome is offline

#### Scenario: Offline without cache
- **WHEN** the device is offline and nothing is cached
- **THEN** no forecast is returned, the outcome is offline, and the resulting verdict is Unknown

#### Scenario: Some ring points fail
- **WHEN** the requests for the SW and W points fail and the rest succeed
- **THEN** the outcome is partial, naming SW and W, and the successful samples are returned

### Requirement: Weather attribution
Every app screen that presents weather-derived information, including verdicts, SHALL show the Apple Weather mark matching the current light or dark appearance, and a link to Apple's weather data attribution page. Widgets and the watch app SHALL show attribution wherever Apple's WeatherKit guidelines require it.

#### Scenario: Verdict screen
- **WHEN** a screen shows a verdict or any forecast value
- **THEN** the Apple Weather mark and a working attribution link are visible on that screen

### Requirement: Development weather source
Debug builds SHALL offer a fixture weather source with named scenarios (at least: clear day, afternoon rain, storm to the north, freezing morning, gusty) that makes no network requests. Release builds SHALL always use the live weather service.

#### Scenario: Debug fixture
- **WHEN** a debug build is launched with the fixture source and the "storm to the north" scenario selected
- **THEN** forecasts come from the fixture, no network request is made, and the north sample points show thunderstorms

#### Scenario: Release build
- **WHEN** a release build runs
- **THEN** the fixture source can't be selected
