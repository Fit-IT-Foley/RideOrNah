# ride-verdict Specification

## Purpose
Defines how hourly forecasts across the ride radius, a rider's limits and their ride windows become a Ride, Maybe, Nah or Unknown verdict, with reasons, a direction summary, a 7-day outlook and ride opportunities.

## Requirements

### Requirement: Verdict states
The system SHALL express every evaluation as one of four verdicts: Ride (no limit breached), Maybe (at least one soft limit breached and no hard limit breached), Nah (at least one hard limit breached), or Unknown (not enough fresh data to decide). Severity SHALL be ordered Ride < Maybe < Nah.

#### Scenario: Clean forecast
- **WHEN** no enabled limit is breached in any evaluated hour at any sample point
- **THEN** the verdict is Ride

#### Scenario: Only soft breaches
- **WHEN** a soft limit is breached and no hard limit is breached
- **THEN** the verdict is Maybe

#### Scenario: Any hard breach
- **WHEN** a hard limit is breached in at least one evaluated hour at at least one sample point
- **THEN** the verdict is Nah, regardless of how many hours are clean

### Requirement: Evaluated hours follow ride windows
The system SHALL evaluate a day using only the forecast hours that overlap the active profile's ride windows for that weekday, interpreted in the device's current time zone. An hour overlaps a window if any part of it falls inside the window. Each ride window SHALL get its own verdict, and the day verdict SHALL be the most severe of its window verdicts.

#### Scenario: Window boundaries
- **WHEN** a ride window runs 07:30–09:00
- **THEN** the 07:00 and 08:00 forecast hours are evaluated and the 09:00 hour is not

#### Scenario: Rain outside the windows
- **WHEN** heavy rain is forecast for 12:00–14:00 and the only ride windows are 07:00–09:00 and 16:00–18:00, both clean
- **THEN** the day verdict is Ride

#### Scenario: One bad window
- **WHEN** the morning window is Ride and the evening window is Nah
- **THEN** the day verdict is Nah, and each window's own verdict is reported

### Requirement: Days without a ride window
When the active profile has no ride window on a given weekday, the system SHALL evaluate that day's daylight hours (sunrise to sunset at the evaluation location) and mark the day as having no scheduled ride window. For the current day, it SHALL evaluate only the daylight hours that haven't ended. After sunset, it SHALL report that no daylight remains today instead of a verdict. When sunrise and sunset are unavailable for a day, that day's daylight evaluation SHALL be Unknown.

#### Scenario: Weekend-only rider on a Tuesday
- **WHEN** the profile's only windows are on Saturday and Sunday and the day evaluated is a Tuesday
- **THEN** the Tuesday verdict covers sunrise to sunset and is marked "no ride window scheduled"

#### Scenario: Afternoon check
- **WHEN** it is 14:00 on a day without windows and sunset is at 17:30
- **THEN** only the 14:00 through 17:00 hours are evaluated

#### Scenario: After sunset
- **WHEN** it is 18:00 on a day without windows and sunset was at 17:30
- **THEN** today reports "no daylight remaining" and no verdict

#### Scenario: Missing sun times
- **WHEN** a day without windows has no sunrise or sunset data
- **THEN** that day's verdict is Unknown

### Requirement: Ended windows today
For the current day, the system SHALL exclude ride windows that have already ended from the day verdict and report them as ended. When every window for today has ended, the system SHALL report that no ride windows remain today instead of a verdict.

#### Scenario: Morning window already over
- **WHEN** it is 12:00 and today's windows are 07:00–09:00 (rainy) and 16:00–18:00 (clean)
- **THEN** the day verdict is Ride, and the morning window is reported as ended

#### Scenario: All windows over
- **WHEN** it is 19:00 and today's last window ended at 18:00
- **THEN** today reports "no ride windows remaining" and no verdict

### Requirement: Factor limits are configurable per factor
Each factor SHALL be individually enabled or disabled, and, apart from ice risk and severe weather alerts (whose severities are fixed by their own requirements), SHALL accept an optional soft limit and an optional hard limit. A disabled factor, or a limit left unset, SHALL never contribute to a verdict. A value exactly at a limit SHALL count as breaching it: at or above for upper limits (such as heat or wind), at or below for lower limits (such as cold or visibility).

#### Scenario: Value exactly at the limit
- **WHEN** gusts are exactly equal to the soft gust limit
- **THEN** gusts produce a soft breach

#### Scenario: Disabled factor
- **WHEN** the UV factor is disabled and the UV index is 11
- **THEN** UV produces no breach

#### Scenario: Soft-only factor
- **WHEN** the UV factor has a soft limit of 8 and no hard limit, and the UV index is 11
- **THEN** UV produces a soft breach only

### Requirement: Missing values
When an hour lacks a value at a sample point, the factors that need that value SHALL be reported as not checked for that hour and point. When the evaluation location lacks precipitation chance, air temperature, feels-like temperature or sustained wind for any evaluated hour of a window, that window SHALL be Unknown. At a ring point, an hour missing any of those values SHALL count as that point having no data for that hour. The gust, visibility, wet-road and alert requirements refine this rule for their own data.

#### Scenario: UV missing
- **WHEN** the UV index is missing for every hour of a window and nothing else is breached
- **THEN** the window is Ride, and UV is reported as not checked

#### Scenario: Temperature missing here
- **WHEN** the evaluation location has no air temperature for the 08:00 hour of a 07:00–09:00 window
- **THEN** that window is Unknown

### Requirement: Precipitation and storms
The system SHALL compare each hour's precipitation chance and precipitation intensity against the precipitation limits. Breaching either one counts as a breach at that level. A forecast thunderstorm or hail in an evaluated hour SHALL always count as a hard breach while the precipitation factor is enabled.

#### Scenario: Chance exceeds the hard limit
- **WHEN** the hard limit for precipitation chance is 60% and an evaluated hour shows 70%
- **THEN** precipitation produces a hard breach

#### Scenario: Low chance but heavy intensity
- **WHEN** the chance is 40%, under both limits, but intensity is 2 mm/h (0.08 in/h) and the hard intensity limit is 1 mm/h (0.04 in/h)
- **THEN** precipitation produces a hard breach

#### Scenario: Thunderstorm
- **WHEN** a thunderstorm is forecast in an evaluated hour while precipitation chance and intensity are both under their limits
- **THEN** precipitation produces a hard breach

### Requirement: Temperature and humidity
The system SHALL compare air temperature against the cold limits, feels-like temperature against the heat limits, and relative humidity against the humidity limits.

#### Scenario: Cold morning
- **WHEN** the soft cold limit is 50 °F (10 °C), the hard cold limit is 40 °F (4.4 °C), and an evaluated hour is 45 °F (7.2 °C)
- **THEN** cold produces a soft breach

#### Scenario: Muggy afternoon
- **WHEN** the air temperature is 88 °F (31 °C) but the feels-like temperature is 101 °F (38.3 °C), and the hard heat limit is 100 °F (37.8 °C)
- **THEN** heat produces a hard breach

### Requirement: Wind and gusts
The system SHALL compare sustained wind speed and gust speed against their own separate limits. When gust data is missing, only sustained wind SHALL be evaluated, and gusts SHALL be reported as not checked.

#### Scenario: Calm average, strong gusts
- **WHEN** sustained wind is 12 mph (19 km/h), under its limits, and gusts are 42 mph (68 km/h) with a hard gust limit of 40 mph (64 km/h)
- **THEN** gusts produce a hard breach

#### Scenario: Gust data missing
- **WHEN** gust data is missing and sustained wind is under its limits
- **THEN** no wind breach is produced, and gusts are reported as not checked

### Requirement: UV index
The system SHALL compare the hourly UV index against the UV limits.

#### Scenario: High UV
- **WHEN** the soft UV limit is 8 and an evaluated hour has a UV index of 9
- **THEN** UV produces a soft breach

### Requirement: Wet roads after rain
The system SHALL treat roads as wet at a sample point for a rider-set number of hours after the last hour with measurable precipitation (0.1 mm/h, 0.004 in/h, or more). This includes precipitation before the ride window starts. Wet roads SHALL breach at the level the rider assigns to this factor.

#### Scenario: Rain ended before the commute
- **WHEN** wet-road duration is 2 hours at the soft level, rain ends at 06:00, and the ride window starts at 07:00
- **THEN** wet roads produce a soft breach for the 07:00 hour and none for 08:00 onward

#### Scenario: No lookback data
- **WHEN** forecast data for the hours before the window is unavailable
- **THEN** wet roads are evaluated only from the hours available, and the factor is reported as partially checked

### Requirement: Ice risk
The system SHALL report a hard ice breach for an evaluated hour when frozen precipitation (snow, sleet, freezing rain, wintry mix) is forecast. It SHALL also report a hard ice breach when the air temperature is at or below the profile's ice threshold and either the roads are wet (per the wet-roads rule) or relative humidity is 95% or higher.

#### Scenario: Cold and damp
- **WHEN** the ice threshold is 37 °F (3 °C), the hour is 34 °F (1 °C), and it rained two hours earlier within the wet-road duration
- **THEN** ice produces a hard breach

#### Scenario: Cold but dry
- **WHEN** the hour is 34 °F (1 °C), humidity is 60%, and roads are not wet
- **THEN** ice produces no breach, and the cold factor is still evaluated on its own

### Requirement: Visibility and fog
The system SHALL compare forecast visibility against the visibility limits. When visibility data is missing but fog is forecast, fog SHALL count as a soft breach.

#### Scenario: Dense fog
- **WHEN** the hard visibility limit is 0.25 mi (400 m) and visibility is 0.1 mi (160 m)
- **THEN** visibility produces a hard breach

#### Scenario: Fog without visibility data
- **WHEN** visibility data is missing and fog is forecast for an evaluated hour
- **THEN** visibility produces a soft breach

### Requirement: Severe weather alerts
The system SHALL treat an official weather alert that covers any sample point as follows: severity "severe" or "extreme" is a hard breach, "moderate" is a soft breach, and "minor" is ignored. When an alert gives its active period, it SHALL apply only to the evaluated hours inside that period. When it gives no active period, it SHALL apply to the current day only. When alert data is unavailable for the region, the system SHALL report alerts as not checked.

#### Scenario: Severe thunderstorm warning
- **WHEN** a "severe" alert covers the northeast sample point during an evaluated hour
- **THEN** the verdict is Nah, and the breach names the alert and the northeast direction

#### Scenario: Moderate alert
- **WHEN** a "moderate" alert covers a sample point during an evaluated hour and nothing else is breached
- **THEN** the verdict is Maybe

#### Scenario: Minor alert
- **WHEN** a "minor" alert covers a sample point during an evaluated hour and nothing else is breached
- **THEN** the verdict is Ride

#### Scenario: Alert ends before the window
- **WHEN** a "severe" alert's active period ends at 06:00 and the ride window starts at 07:00
- **THEN** the alert produces no breach for that window

#### Scenario: Alert without an active period
- **WHEN** a "severe" alert gives no active period
- **THEN** today's verdict is Nah, and the verdicts of later days are unaffected by it

#### Scenario: Alerts unsupported in the region
- **WHEN** the weather source provides no alert data for the location
- **THEN** no alert breach is produced, and the evaluation reports alerts as not checked

### Requirement: Worst case across the ride radius
The system SHALL evaluate every hour at every sample point in the ride radius, and the most severe result at any sample point SHALL determine the verdict.

#### Scenario: Storm at the edge of the radius
- **WHEN** the evaluation location is clear but the west sample point has a hard precipitation breach during a window
- **THEN** the verdict is Nah, and the breach is attributed to the west

### Requirement: Direction summary
When the ride radius has ring sample points, the system SHALL report a verdict for each of the eight compass directions (N, NE, E, SE, S, SW, W, NW) and for the evaluation location itself. Each direction's verdict SHALL be the most severe of that direction's sample points. A direction whose sample points have no data SHALL be Unknown and SHALL NOT be listed as clear. The system SHALL list the clear directions (Ride).

#### Scenario: Rain to the north only
- **WHEN** only the N and NE sample points have breaches
- **THEN** the direction summary marks N and NE with their verdicts and lists E, SE, S, SW, W and NW as clear

#### Scenario: Missing direction
- **WHEN** the SW sample point has no data and every other point is clear
- **THEN** SW is Unknown, and the clear directions are N, NE, E, SE, S, W and NW

#### Scenario: Local radius
- **WHEN** the ride radius is local (no ring points)
- **THEN** no direction summary is produced

### Requirement: Explained verdicts
Every Maybe or Nah verdict SHALL list each breach with: the factor, the severity (soft or hard), the worst forecast value, the limit it crossed, the time range (consecutive breached hours merged), and the affected directions or the evaluation location. Breaches SHALL be ordered by severity, then by start time.

#### Scenario: Merged time range
- **WHEN** gusts breach the soft limit at 16:00, 17:00 and 18:00 to the west, peaking at 34 mph (55 km/h) against a 30 mph (48 km/h) limit
- **THEN** one breach is reported for 16:00–19:00, to the west, with a worst value of 34 mph (55 km/h) and a limit of 30 mph (48 km/h)

### Requirement: Missing and stale data never yields Ride
The system SHALL report Unknown for a window when the evaluation location's forecast has no data for any of that window's hours. When ring sample points are missing, the system SHALL evaluate with the points available and report partial coverage, naming the missing directions. For today, it SHALL report Unknown when the forecast is more than 12 hours old, and mark the verdict stale when it is more than 3 hours old. For later days, it SHALL report Unknown when the forecast is more than 24 hours old. A day containing any Unknown window and no Nah window SHALL be Unknown.

#### Scenario: Outdated forecast
- **WHEN** the newest forecast for today was fetched 13 hours ago
- **THEN** today's verdict is Unknown with reason "forecast out of date"

#### Scenario: Stale but usable
- **WHEN** the forecast is 5 hours old and shows no breaches
- **THEN** today's verdict is Ride, marked stale, with the forecast's age

#### Scenario: Later days expire
- **WHEN** the newest forecast was fetched 25 hours ago
- **THEN** days two to seven are Unknown, as well as today

#### Scenario: Missing ring point
- **WHEN** the SW sample point failed to load and every other point is clear
- **THEN** the verdict is Ride with partial coverage, naming SW as missing

#### Scenario: A known Nah outranks Unknown
- **WHEN** one window is Unknown and another is Nah
- **THEN** the day verdict is Nah

### Requirement: Seven-day outlook
The system SHALL produce a verdict for today and each of the next six days using the same rules. Days four through seven (today counts as day one) SHALL be marked lower confidence.

#### Scenario: Outlook confidence
- **WHEN** a 7-day outlook is produced
- **THEN** days one to three are marked normal confidence and days four to seven are marked lower confidence

### Requirement: Ride opportunities
For each outlook day, the system SHALL find ride opportunities: unbroken stretches of daylight hours, not yet ended, in which every sample point has data and every hour is Ride at every sample point, lasting at least the profile's minimum ride duration. The system SHALL return at most three per day, longest first. Opportunities SHALL consider all daylight hours, not only ride windows. A day whose verdict is Unknown SHALL have no opportunities, and no day SHALL have opportunities while coverage is partial.

#### Scenario: Saturday afternoon gap
- **WHEN** Saturday is rainy until 11:00 and clear from 11:00 to sunset at 17:30, with a 2-hour minimum ride duration
- **THEN** one opportunity of 11:00–17:30 is reported for Saturday

#### Scenario: Too short
- **WHEN** the only clear stretch on a day lasts 1 hour and the minimum duration is 2 hours
- **THEN** no opportunity is reported for that day

#### Scenario: Busy good day
- **WHEN** a day has four separate clear stretches of 2, 3, 4 and 5 hours and the minimum duration is 2 hours
- **THEN** the 5-hour, 4-hour and 3-hour stretches are reported, in that order

#### Scenario: Ended hours
- **WHEN** it is 13:00 and today is clear from 09:00 to 17:00
- **THEN** today's opportunity is 13:00–17:00

#### Scenario: No opportunities without data
- **WHEN** coverage is partial, or a day's verdict is Unknown
- **THEN** no opportunities are reported for the affected days

### Requirement: Evaluating a time range
The system SHALL evaluate any time range within the outlook, such as a ride the rider added to their calendar, using the same rules as a ride window, and report its verdict and breaches.

#### Scenario: Added ride turns rainy
- **WHEN** the range Saturday 11:00–17:30 is evaluated and the 15:00 hour has a hard precipitation breach
- **THEN** the range is Nah, with a precipitation breach starting at 15:00

### Requirement: Deterministic evaluation
Given the same forecasts, profile, alerts, current time and time zone, the system SHALL always produce the same verdicts, breaches, direction summary and opportunities.

#### Scenario: Repeat evaluation
- **WHEN** the same inputs are evaluated twice
- **THEN** both results are identical
