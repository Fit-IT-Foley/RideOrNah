# Spec Delta

## Purpose

Puts the rider's verdict on the Home Screen and Lock Screen, using the app's cached forecasts and the same rules as the app, without adding meaningful weather requests.

## ADDED Requirements

### Requirement: Widget families
The system SHALL provide these widgets:
- Home Screen small: today's verdict word, a short reason or "All clear", and forecast age.
- Home Screen medium: the small widget's content plus the verdict for each of the next three days.
- Lock Screen circular: today's verdict.
- Lock Screen rectangular: today's verdict and a short reason.
- Lock Screen inline: today's verdict and a short text.

#### Scenario: Medium widget
- **WHEN** the rider adds the medium widget
- **THEN** it shows today's verdict, a short reason and freshness, and verdicts for the next three days

### Requirement: Same verdict as the app
Widgets SHALL evaluate the active profile at the background location source, with today's radius override, using the same rules as the app. Given the same forecast and settings, a widget SHALL NEVER show a different verdict from the app.

#### Scenario: Matching verdicts
- **WHEN** the app shows Maybe for the background location source
- **THEN** the widget also shows Maybe

### Requirement: Shared data and refresh limits
Widgets SHALL use forecasts from the shared cache. They SHALL request new forecasts only under the widget refresh interval and daily budget defined in `weather-data`. When the app or a background refresh gets new forecasts, or the profile, location source, radius or units change, widgets SHALL update promptly.

#### Scenario: After opening the app
- **WHEN** the app fetches new forecasts
- **THEN** the widgets show the new verdict without making their own request

### Requirement: Timeline follows the day
A widget's content SHALL update when a ride window ends, so ended windows no longer affect today's verdict, and at local midnight. When no windows remain today, the widget SHALL show tomorrow's verdict, labelled as tomorrow.

#### Scenario: Evening
- **WHEN** today's last window ends at 18:00
- **THEN** after 18:00 the widget shows tomorrow's verdict, labelled "Tomorrow"

### Requirement: Stale and unknown in widgets
Widgets SHALL show forecast age when the verdict is stale, and SHALL show a short cause instead of a verdict word when the verdict is Unknown. A widget SHALL NEVER show Ride for Unknown data.

#### Scenario: Old data
- **WHEN** the forecast behind the widget is more than 12 hours old
- **THEN** the widget shows no verdict word and asks the rider to open the app

### Requirement: Lock Screen privacy
Widgets SHALL hide location names while the device is locked.

#### Scenario: Locked device
- **WHEN** the iPhone is locked and the rectangular widget is visible
- **THEN** the verdict and reason are shown, and the location name is not

### Requirement: Locked without access
When the rider has no subscription access, every widget SHALL show a short prompt to subscribe and no weather information.

#### Scenario: Lapsed subscription
- **WHEN** access has ended
- **THEN** the small widget shows a subscribe prompt with no verdict

### Requirement: Tap targets
Tapping a widget SHALL open the app on the Today screen. Tapping a day in the medium widget SHALL open that day's detail.

#### Scenario: Tapping Thursday
- **WHEN** the rider taps Thursday in the medium widget
- **THEN** the app opens on Thursday's day detail

### Requirement: Widget attribution
Widgets SHALL show weather attribution wherever Apple's WeatherKit guidelines require it for widgets. If the guidelines allow attribution in the app alone, the widget SHALL link into the app, where attribution is shown.

#### Scenario: Attribution check
- **WHEN** widgets are reviewed against Apple's current WeatherKit attribution guidelines before release
- **THEN** each widget family meets them
