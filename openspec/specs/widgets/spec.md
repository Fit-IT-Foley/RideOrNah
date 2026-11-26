# widgets Specification

## Purpose
Puts the rider's verdict on the Home Screen and Lock Screen, using the app's cached forecasts and the same rules as the app, without adding meaningful weather requests.

## Requirements

### Requirement: Widget families
The system SHALL provide these widgets:
- Home Screen small: today's verdict word, a short reason or "All clear", and forecast age.
- Home Screen medium: the small widget's content plus the verdict for each of the next three days, with day four (a lower-confidence day) labelled as lower confidence.
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
A widget's timeline SHALL include entries for when a ride window ends, so ended windows no longer affect today's verdict, and for local midnight. It SHALL also include entries for when the forecast becomes stale (3 hours old) and when it expires (12 hours old), so the widget changes on time even if no refresh happens. When no windows remain today, the widget SHALL show tomorrow's verdict, labelled as tomorrow.

#### Scenario: Evening
- **WHEN** today's last window ends at 18:00
- **THEN** after 18:00 the widget shows tomorrow's verdict, labelled "Tomorrow"

#### Scenario: Data ages without a refresh
- **WHEN** the widget shows Ride from a forecast fetched at 06:00 and no refresh happens all day
- **THEN** its timeline marks the verdict as older from 09:00, and shows no verdict word from 18:00

### Requirement: Stale and unknown in widgets
Widgets SHALL show forecast age when the verdict is stale, and SHALL show a short cause instead of a verdict word when the verdict is Unknown. A widget SHALL NEVER show Ride for Unknown data.

#### Scenario: Old data
- **WHEN** the forecast behind the widget is more than 12 hours old
- **THEN** the widget shows no verdict word and asks the rider to open the app

### Requirement: Lock Screen privacy
Any widget content that names a location SHALL be marked privacy-sensitive, so the system hides it while the device is locked.

#### Scenario: Locked device
- **WHEN** a widget that shows a location name is rendered with privacy redaction, as on a locked device
- **THEN** the verdict and reason are shown, and the location name is hidden

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
Each widget family that shows a verdict or forecast value SHALL either show the Apple Weather mark, or open an app screen that shows the mark and the attribution link when tapped. Before release, the families SHALL be checked against Apple's current WeatherKit attribution guidelines. That review goes in `docs/manual-checks.md` when this capability is archived.

#### Scenario: Attribution through the app
- **WHEN** the rider taps a widget family that doesn't show the Apple Weather mark itself
- **THEN** the app opens on a screen that shows the mark and the attribution link

#### Scenario: Attribution review
- **WHEN** a release is prepared
- **THEN** each widget family has been checked against Apple's current WeatherKit attribution guidelines
