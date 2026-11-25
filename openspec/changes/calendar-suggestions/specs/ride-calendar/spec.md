# Spec Delta

## Purpose

Lets riders opt in to ride suggestions for good-weather stretches in the week ahead, and add any of them to their calendar in one tap through the system editor, without the app accessing their calendar.

## ADDED Requirements

### Requirement: Opt-in ride suggestions
The system SHALL offer a "Ride suggestions" setting, off by default. While it's off, no suggestions or calendar actions SHALL appear anywhere.

#### Scenario: Default off
- **WHEN** a new rider views the outlook
- **THEN** no ride suggestions or "Add to Calendar" actions appear

### Requirement: Showing suggestions
While ride suggestions are on, the outlook and each day detail SHALL show that day's ride opportunities (at most three, longest first) with their time ranges. Suggestions on lower-confidence days SHALL carry the lower-confidence label. Days whose verdict is Unknown, or whose forecast is stale, SHALL show no suggestions.

#### Scenario: Clear Saturday afternoon
- **WHEN** Saturday has an opportunity from 11:00 to 17:30
- **THEN** Saturday shows a suggestion for 11 AM–5:30 PM with an "Add to Calendar" action

#### Scenario: Stale forecast
- **WHEN** the forecast is stale
- **THEN** no suggestions are shown until it refreshes

### Requirement: Adding through the system editor
Choosing "Add to Calendar" SHALL open the system event editor, pre-filled with: the title "Ride" followed by the profile name; the opportunity's start and end; the evaluation location's name; and notes summarizing the forecast and when it was fetched, with a reminder to check RideOrNah before leaving. The rider SHALL be able to edit, save or cancel. The system SHALL NOT request calendar permission, and SHALL NEVER read, modify or delete calendar events.

#### Scenario: Saving a ride
- **WHEN** the rider taps "Add to Calendar" for Saturday 11:00–17:30 and saves
- **THEN** their calendar contains the event, and no calendar permission prompt has appeared

#### Scenario: Cancelling
- **WHEN** the rider cancels the editor
- **THEN** nothing is added, and the suggestion remains available

### Requirement: Remembering added suggestions
After the rider saves a suggestion, the system SHALL mark it as added and SHALL NOT offer the same time range again. These records SHALL stay on the device and SHALL be deleted after their day has passed.

#### Scenario: Already added
- **WHEN** the rider saved Saturday 11:00–17:30 earlier
- **THEN** that suggestion shows as added, with no "Add to Calendar" action

### Requirement: Warning when an added ride turns bad
When a newer forecast puts any hour of an added suggestion at Maybe or Nah, the system SHALL show a notice in the app naming the ride and the new verdict with its main reason. The system SHALL NOT change the calendar event.

#### Scenario: Rain moves in
- **WHEN** Saturday's added ride from 11:00 to 17:30 now has a hard precipitation breach at 15:00
- **THEN** the app shows a notice that the Saturday ride now looks like Nah, because of rain from 3 PM

### Requirement: Calendar action in the daily notification
While ride suggestions are on and today has at least one ride opportunity, the daily ride notification SHALL include an "Add to Calendar" action. The action SHALL open the app with the system event editor pre-filled for today's longest opportunity.

#### Scenario: Morning action
- **WHEN** the morning notification arrives on a day with an opportunity from 10:00 to 15:00, and the rider chooses "Add to Calendar"
- **THEN** the app opens with the event editor pre-filled for 10 AM–3 PM
