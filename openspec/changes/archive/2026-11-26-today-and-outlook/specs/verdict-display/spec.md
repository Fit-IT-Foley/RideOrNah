# Spec Delta

## Purpose

Defines what riders see on the Today screen, the 7-day outlook and the day detail in every state, and how they refresh and change profile, location and radius from there.

## ADDED Requirements

### Requirement: Today verdict at a glance
The Today screen SHALL show the verdict as a word (Ride, Maybe or Nah), a one-line summary, the active profile name, the evaluation location name, and today's ride radius. The summary SHALL be "Clear for all your ride windows" for Ride. For Maybe and Nah, it SHALL name the most severe breach's factor, its worst value and its time range.

#### Scenario: Nah from rain
- **WHEN** today's verdict is Nah because of a hard precipitation breach from 17:00 to 19:00
- **THEN** Today shows "Nah", with a summary naming rain, its 70% chance and 5–7 PM

#### Scenario: Clean day
- **WHEN** today's verdict is Ride
- **THEN** Today shows "Ride" with "Clear for all your ride windows"

### Requirement: Ride windows on Today
The Today screen SHALL list today's ride windows in time order, each with its time range and verdict. Ended windows SHALL be labelled as ended. When all of today's windows have ended, the screen SHALL say so and show tomorrow's verdict. When the active profile has windows but none today, the screen SHALL note that no ride is planned today and show the daylight-hours verdict. When the profile has no windows at all (the Anytime preset), the screen SHALL show the daylight-hours verdict without that note.

#### Scenario: Done for today
- **WHEN** it is 19:00 and today's last window ended at 18:00
- **THEN** Today says today's riding windows are over and shows tomorrow's verdict

#### Scenario: Anytime rider
- **WHEN** the active profile has no ride windows
- **THEN** Today shows the sunrise-to-sunset verdict with no "no ride planned" note

### Requirement: Reasons in the rider's terms
For Maybe and Nah, the system SHALL list every breach with the factor in plain words, the worst forecast value and the limit in the rider's units, the time range, and where it occurs ("here" or compass directions). Hard breaches SHALL be listed before soft ones.

#### Scenario: Gust reason
- **WHEN** units are imperial and a soft gust breach peaks at 34 mph (55 km/h) against a 30 mph (48 km/h) limit, 4–7 PM, to the west
- **THEN** the reason names gusts, 34 mph, the 30 mph limit, 4–7 PM and the west

### Requirement: Direction summary on Today
When the ride radius isn't Local and the verdict isn't Ride, the Today screen SHALL say which compass directions are clear, or that no direction is clear.

#### Scenario: Clear to the south
- **WHEN** only N, NE and NW have breaches
- **THEN** Today shows that it's clear to the E, SE, S, SW and W

#### Scenario: Bad everywhere
- **WHEN** every direction has a breach
- **THEN** Today says no direction in the radius is clear

### Requirement: Freshness and coverage
The Today screen SHALL show how long ago the forecast was updated. It SHALL mark a stale verdict (forecast more than 3 hours old) as based on an older forecast, and SHALL say when refreshing is paused by the daily budget, when the device is offline, and when some directions couldn't be checked (naming them). It SHALL say when severe weather alerts couldn't be checked for the area.

#### Scenario: Stale verdict
- **WHEN** the forecast is 5 hours old
- **THEN** Today shows the verdict marked as based on an older forecast, and says it was updated 5 hours ago

#### Scenario: Partial coverage
- **WHEN** the SW point failed to load
- **THEN** Today notes that the southwest couldn't be checked

### Requirement: Unknown states explain the cause
When today's verdict is Unknown, the Today screen SHALL NOT show Ride, Maybe or Nah. It SHALL state the cause and the next step: no location (add a location), offline with no usable forecast (connect and refresh), forecast too old (refresh), refreshing paused for today by the daily request limit with no usable forecast (check again tomorrow), weather service unavailable (try again later), or not authorized (update the app).

#### Scenario: Offline first launch
- **WHEN** the app has no cached forecast and the device is offline
- **THEN** Today says it can't check the weather without a connection and offers a retry, with no verdict word shown

### Requirement: Refreshing
Opening the app or returning it to the foreground SHALL refresh the forecast under the foreground rules in `weather-data`. Pulling to refresh SHALL request a manual refresh. When the weather layer reports the forecast as already current, the screen SHALL say it's up to date.

#### Scenario: Pull too soon
- **WHEN** the rider pulls to refresh 5 minutes after an update
- **THEN** the screen says the forecast is already up to date, and no request is made

### Requirement: Changing profile, location and radius from Today
From the Today screen, the rider SHALL be able to switch the active profile, the evaluation location, and today's radius override. The verdict SHALL update right away from cached forecasts when they cover the new choice, and otherwise after fetching.

#### Scenario: Switching to a smaller radius
- **WHEN** the rider changes today's radius from 25 mi (40 km) to 10 mi (16 km)
- **THEN** the verdict updates, using cached data if available

### Requirement: Seven-day outlook
The system SHALL show today and the next six days, each with its verdict word and one-line summary. Days four to seven SHALL be marked as lower confidence. Days with an Unknown verdict SHALL say why.

#### Scenario: Outlook confidence marker
- **WHEN** the outlook is shown
- **THEN** days four to seven carry a lower-confidence label, and days one to three don't

### Requirement: Day detail
Selecting a day SHALL show the hours that were evaluated (the ride windows, or daylight), each with temperature, feels-like, precipitation chance, wind and gusts, and UV at the evaluation location. A value the forecast doesn't include SHALL be shown as unavailable, never as zero. Any hour with a breach SHALL be marked with its severity and the factor. The day detail SHALL list that day's reasons, as on Today.

#### Scenario: Hour with a breach
- **WHEN** the 17:00 hour has a hard precipitation breach
- **THEN** that hour is marked hard with the precipitation factor, and the other hours show their values unmarked

#### Scenario: Missing value in the detail
- **WHEN** the forecast has no UV index for the 17:00 hour
- **THEN** that hour shows UV as unavailable, not as zero

### Requirement: Attribution on weather screens
The Today, outlook and day-detail screens SHALL each show the weather attribution required by `weather-data`.

#### Scenario: Day detail attribution
- **WHEN** the rider opens a day detail
- **THEN** the Apple Weather mark and the attribution link are visible on that screen

### Requirement: Day rollover
When the app stays open across local midnight, the Today screen SHALL switch to the new day, clear today's radius override, and re-evaluate without the rider having to act.

#### Scenario: Midnight with the app open
- **WHEN** the app is open on Today at 23:59 and the clock passes midnight
- **THEN** Today shows the new day's verdict with the profile's default radius

### Requirement: Current conditions
The Today screen SHALL show the current hour's air temperature, feels-like temperature and precipitation chance at the evaluation location, in the rider's units. A value the forecast doesn't include SHALL be shown as unavailable.

#### Scenario: Current hour values
- **WHEN** units are imperial and the current hour is 54 °F (12.2 °C) air, 51 °F (10.6 °C) feels-like, with an 80% rain chance
- **THEN** Today shows 54°, 51° and 80%

### Requirement: Room to your limits
When today's verdict is Ride, the Today screen SHALL show, for rain chance, gusts, cold and UV, the worst forecast value in today's evaluated hours at any sample point, next to the soft limit that would make it a Maybe.

#### Scenario: Comfortable margins
- **WHEN** today is Ride, the worst rain chance in the evaluated hours is 0%, and the soft rain-chance limit is 30%
- **THEN** Today shows 0% for rain chance against "Maybe at 30%"

### Requirement: Daylight
The Today screen SHALL show today's sunrise and sunset at the evaluation location and the length of daylight between them. It SHALL leave this out when sun times are unavailable.

#### Scenario: Sun times
- **WHEN** sunrise is 6:38 AM and sunset is 4:46 PM
- **THEN** Today shows both times and "10h 08m of light"
