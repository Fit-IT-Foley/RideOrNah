# Spec Delta

## Purpose

Brings the rider's verdict to Apple Watch through an app and watch-face complications, fed by results evaluated on the paired iPhone, so the watch adds no weather requests.

## ADDED Requirements

### Requirement: Watch app content
The watch app SHALL show today's verdict word, today's ride windows with their verdicts, the most severe reasons, the clear directions when the radius isn't Local, the active profile and location names, and the verdict for each of the next six days. Days four to seven SHALL be marked lower confidence.

#### Scenario: Opening the watch app
- **WHEN** the rider opens the watch app after the iPhone has evaluated today
- **THEN** the watch shows the same verdict, windows and main reasons as the iPhone

### Requirement: Complications
The system SHALL provide complications for the circular, rectangular, inline and corner watch-face families. Each SHALL show today's verdict; the rectangular family SHALL also show a short reason. Tapping a complication SHALL open the watch app.

#### Scenario: Rectangular complication
- **WHEN** today's verdict is Nah because of rain from 5 PM
- **THEN** the rectangular complication shows "Nah" and a short reason about rain from 5 PM

### Requirement: Results come from the iPhone
The iPhone SHALL send the watch its latest evaluated results: verdicts, reasons, windows, direction summary, outlook, fetch time and access state. It SHALL send them every time it re-evaluates, including after background refreshes. The watch SHALL NEVER request weather data itself.

#### Scenario: Background update
- **WHEN** a background refresh on the iPhone produces a new verdict
- **THEN** the watch receives it the next time the system delivers the update, and the complication updates

### Requirement: Freshness on the watch
The watch SHALL show how old the results are. When results are more than 3 hours old, the watch SHALL mark the verdict as out of date. When they're more than 12 hours old, or the watch has never received results, it SHALL show no verdict and SHALL ask the rider to open RideOrNah on their iPhone.

#### Scenario: Phone left at home
- **WHEN** the watch hasn't received results for 13 hours
- **THEN** the watch app and complications show no verdict word, and the watch app asks the rider to open the iPhone app

### Requirement: Locked without access
When the iPhone reports no subscription access, the watch app and complications SHALL show a short prompt to subscribe on the iPhone and no weather information.

#### Scenario: Lapsed subscription
- **WHEN** access ends on the iPhone
- **THEN** after the next update, the watch shows the subscribe prompt with no verdict

### Requirement: Watch privacy
Complications SHALL hide location names while the watch is locked or the wrist is down.

#### Scenario: Wrist down
- **WHEN** the rider lowers their wrist
- **THEN** complications show the verdict without the location name
