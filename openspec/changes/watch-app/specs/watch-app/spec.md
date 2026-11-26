# Spec Delta

## Purpose

Brings the rider's verdict to Apple Watch through an app and watch-face complications, fed by results evaluated on the paired iPhone, so the watch adds no weather requests.

## ADDED Requirements

### Requirement: Watch app content
The watch app SHALL show today's verdict word, today's ride windows with their verdicts, the most severe reasons, the clear directions when the radius isn't Local, the active profile and location names, and the verdict for each of the next six days. Days four to seven SHALL be marked lower confidence.

#### Scenario: Showing received results
- **WHEN** the watch has received results that include today
- **THEN** the watch app shows the verdict, windows and main reasons those results contain for today

### Requirement: Complications
The system SHALL provide complications for the circular, rectangular, inline and corner watch-face families. Each SHALL show today's verdict, and the rectangular family SHALL also show a short reason. Tapping a complication SHALL open the watch app.

#### Scenario: Rectangular complication
- **WHEN** today's verdict is Nah because of rain from 5 PM
- **THEN** the rectangular complication shows "Nah" and a short reason naming rain and 5 PM

### Requirement: Results come from the iPhone
The iPhone SHALL send the watch its latest evaluated results whenever it re-evaluates, including after background refreshes. Results SHALL carry, for each outlook date, that date's verdict, ride windows with their times and verdicts, main reasons and direction summary, plus the fetch time and the subscription access state. On receiving results, the watch SHALL store them, update the app and reload its complications. The watch SHALL NEVER request weather data itself. Delivery between real paired devices is checked by hand, and goes in `docs/manual-checks.md` when this capability is archived.

#### Scenario: Sending after a background refresh
- **WHEN** a background refresh on the iPhone produces a new evaluation
- **THEN** the iPhone sends the new results to the watch

#### Scenario: Receiving results
- **WHEN** the watch receives new results
- **THEN** it stores them, the app shows them, and the complications reload

### Requirement: The watch follows the day
The watch SHALL show the entry for the current local date from the results it holds, and SHALL drop today's ride windows once they've ended. At local midnight it SHALL move to the next date's entry without needing new results. When no windows remain today, it SHALL show tomorrow's verdict, labelled as tomorrow.

#### Scenario: Past midnight with no update
- **WHEN** the watch last received results yesterday and the local date has changed
- **THEN** it shows the new date's verdict from those results, not yesterday's

#### Scenario: Evening on the watch
- **WHEN** today's last window ended at 18:00
- **THEN** after 18:00 the watch shows tomorrow's verdict, labelled as tomorrow

### Requirement: Freshness on the watch
The watch SHALL show how old the results are. When results are more than 3 hours old, the watch SHALL mark the verdict as based on an older forecast. When they're more than 12 hours old, or the watch has never received results, it SHALL show no verdict and SHALL ask the rider to open RideOrNah on their iPhone. Complication timelines SHALL include entries for the 3-hour and 12-hour points, so complications change on time without new results.

#### Scenario: Phone left at home
- **WHEN** the watch hasn't received results for 13 hours
- **THEN** the watch app and complications show no verdict word, and the watch app asks the rider to open the iPhone app

#### Scenario: Complication ages without an update
- **WHEN** a complication shows Ride from results fetched at 06:00 and nothing new arrives
- **THEN** its timeline marks the verdict as older from 09:00, and shows no verdict word from 18:00

### Requirement: Locked without access
When the iPhone reports no subscription access, the watch app and complications SHALL show a short prompt to subscribe on the iPhone and no weather information.

#### Scenario: Lapsed subscription
- **WHEN** the watch receives results whose access state says access has ended
- **THEN** the watch shows the subscribe prompt with no verdict

### Requirement: Watch privacy
Any complication content that names a location SHALL be marked privacy-sensitive, so the system hides it while the watch is locked or the wrist is down.

#### Scenario: Wrist down
- **WHEN** a complication that shows a location name is rendered with privacy redaction, as when the wrist is down
- **THEN** the verdict is shown and the location name is hidden

### Requirement: Watch attribution
The watch app's main screen SHALL show the Apple Weather mark. Complications SHALL open the watch app when tapped, where the mark is shown.

#### Scenario: Main screen attribution
- **WHEN** the watch app shows a verdict
- **THEN** the Apple Weather mark is visible on that screen
