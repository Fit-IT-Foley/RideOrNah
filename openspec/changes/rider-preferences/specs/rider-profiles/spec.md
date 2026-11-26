# Spec Delta

## Purpose

Lets each rider describe how they ride, with named profiles holding weather limits, ride windows and riding defaults. It covers first-run setup, units, and keeping preferences in sync through the rider's own iCloud.

## ADDED Requirements

### Requirement: Multiple profiles with one active
The system SHALL let the rider create, rename, duplicate and delete profiles. Exactly one profile SHALL be active at any time. The last remaining profile SHALL NOT be deletable. Switching the active profile SHALL immediately re-evaluate verdicts with the new profile.

#### Scenario: Switching bikes
- **WHEN** the rider switches the active profile from "Commuter" to "Adventure"
- **THEN** every verdict is re-evaluated with the Adventure profile's limits, windows and radius

#### Scenario: Deleting the last profile
- **WHEN** only one profile exists
- **THEN** the delete action is unavailable for it

#### Scenario: Deleting the active profile
- **WHEN** the rider deletes the active profile and others exist
- **THEN** the most recently used remaining profile becomes active

### Requirement: Default limits for new profiles
A newly created profile SHALL start with these limits. A value at the limit counts as a breach. Limits are stored in SI units (the metric values below). The imperial values are those limits rounded for display.

| Factor | Direction | Soft limit | Hard limit | Enabled |
|---|---|---|---|---|
| Precipitation chance | at or above | 30% | 60% | yes |
| Precipitation intensity | at or above | 0.1 mm/h (0.004 in/h) | 1 mm/h (0.04 in/h) | yes |
| Cold (air temperature) | at or below | 50 °F (10 °C) | 40 °F (4.4 °C) | yes |
| Heat (feels-like) | at or above | 90 °F (32 °C) | 100 °F (37.8 °C) | yes |
| Humidity | at or above | 85% | none | no |
| Sustained wind | at or above | 20 mph (32 km/h) | 30 mph (48 km/h) | yes |
| Gusts | at or above | 30 mph (48 km/h) | 40 mph (64 km/h) | yes |
| UV index | at or above | 8 | none | yes |
| Wet roads | duration after rain | 2 hours, soft | none | yes |
| Ice risk | at or below the ice threshold | always hard | threshold 37 °F (3 °C) | yes |
| Visibility | at or below | 1 mi (1.6 km) | 0.25 mi (400 m) | yes |
| Severe weather alerts | alert severity | moderate (fixed) | severe or extreme (fixed) | yes |

New profiles SHALL also default to a minimum ride duration of 2 hours and a ride radius of 25 mi (40 km).

#### Scenario: Fresh profile
- **WHEN** the rider creates a new profile
- **THEN** it has exactly the limits in the table, a 2-hour minimum ride duration, and a 25 mi (40 km) radius

#### Scenario: Reset to defaults
- **WHEN** the rider chooses "Reset limits" on a profile
- **THEN** that profile's limits return to the table values, and its name, windows and radius are unchanged

### Requirement: Editing limits
For each factor, the rider SHALL be able to turn the factor on or off and set or clear its soft and hard limits, in their display units. Ice risk and severe weather alerts SHALL offer only on or off, plus the ice threshold, because the verdict rules fix their severities. The system SHALL reject a soft limit that is more severe than the hard limit, explaining why, and SHALL reject values outside the physical range for the factor. Wet-road duration SHALL be adjustable from 0 to 12 hours, and minimum ride duration from 30 minutes to 8 hours.

#### Scenario: Soft beyond hard
- **WHEN** the rider sets the soft gust limit to 45 mph (72 km/h) while the hard gust limit is 40 mph (64 km/h)
- **THEN** the change is rejected, with an explanation that the soft limit must be lower than the hard limit

#### Scenario: Clearing a hard limit
- **WHEN** the rider clears the hard UV limit
- **THEN** UV can produce at most a soft breach

### Requirement: Ride windows
Each profile SHALL hold zero or more ride windows. Each window has a set of weekdays and a start and end time on the same day, with the end after the start. Windows on the same weekday SHALL NOT overlap. Each weekday SHALL hold at most 4 windows. Setup SHALL offer three riding-style presets: Commute (Monday–Friday 07:00–09:00 and 16:00–18:00), Weekends (Saturday and Sunday 09:00–17:00), and Anytime (no windows, so every day is judged on daylight hours).

#### Scenario: Overlapping window
- **WHEN** the rider adds Monday 08:00–10:00 while Monday 07:00–09:00 exists
- **THEN** the window is rejected with an explanation of the overlap

#### Scenario: Anytime preset
- **WHEN** the rider picks the Anytime preset
- **THEN** the profile has no windows, and each day is evaluated from sunrise to sunset

### Requirement: Units
The system SHALL display temperatures, speeds, distances, visibility and precipitation in the unit system of the device region by default. The rider SHALL be able to override it with imperial or metric. Changing units SHALL change only how values are displayed and entered, never the stored limits.

#### Scenario: Override to metric
- **WHEN** a rider in the US switches units to metric
- **THEN** a 30 mph gust limit is shown as 48 km/h, and verdicts are unchanged

### Requirement: First-run setup
On first launch, the system SHALL guide the rider through: choosing a riding-style preset; optionally reviewing the main limits (precipitation chance, cold, heat, wind and gusts), with an option to keep the defaults; and setting up a location (see `ride-locations`). Later capabilities MAY add steps after the location step (`ride-notifications` adds one). Completing setup SHALL create an active profile named "My Bike", which the rider can rename. Quitting mid-setup SHALL resume setup at the same step on next launch.

#### Scenario: Quick setup
- **WHEN** a new rider picks Commute and keeps the defaults
- **THEN** an active profile "My Bike" exists with the Commute windows and the default limits

#### Scenario: Interrupted setup
- **WHEN** the rider quits after choosing a preset but before finishing setup
- **THEN** the next launch resumes setup after the preset step

### Requirement: Preferences sync through the rider's iCloud
When the rider is signed in to iCloud and sync is on (the default), the system SHALL sync profiles, the active-profile choice, saved locations, the background location source, units and notification settings across the rider's devices through their private iCloud storage. When two devices change the same profile, the most recent change SHALL win for that profile. With sync off or no iCloud account, preferences SHALL stay on the device with no loss of function. The last-seen location, forecast cache and request budget SHALL NEVER sync.

#### Scenario: New iPhone
- **WHEN** the app launches for the first time and the rider's iCloud storage already holds profiles and saved locations from another device
- **THEN** those profiles and saved locations load, and first-run setup is skipped

#### Scenario: No iCloud
- **WHEN** the device has no iCloud account
- **THEN** preferences are saved locally, and no error is shown

#### Scenario: Turning sync off
- **WHEN** the rider turns sync off
- **THEN** current preferences stay on this device, and later changes are not uploaded

### Requirement: Preferences persist
Profiles and settings SHALL survive app relaunches, device restarts and app updates.

#### Scenario: App update
- **WHEN** preferences saved by the previous app version are loaded by the new version
- **THEN** every profile, limit, window and setting is unchanged
