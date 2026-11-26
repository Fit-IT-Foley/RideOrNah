# Spec Delta

## Purpose

Delivers each rider's verdict as a local notification at a time they choose, built entirely on the device, with honest handling of forecast age when iOS limits background refresh.

## ADDED Requirements

### Requirement: Opt-in permission
The system SHALL ask for notification permission only after explaining the daily ride notification, either in the notification step of first-run setup or when the rider turns notifications on in settings. If permission is denied, settings SHALL explain how to enable it in the iOS Settings app, with a direct link.

#### Scenario: Denied permission
- **WHEN** the rider denies notification permission and later opens notification settings
- **THEN** the screen explains that notifications are off in iOS Settings and offers a link there

### Requirement: Notification step in first-run setup
First-run setup SHALL include a step after the location step that explains the daily ride notification, lets the rider pick its time, and offers to turn it on. The rider SHALL be able to skip the step, leaving notifications off without asking for permission.

#### Scenario: Turning it on during setup
- **WHEN** a new rider reaches the notification step and chooses to turn it on
- **THEN** the system asks for notification permission and, if granted, schedules the notification at the chosen time

#### Scenario: Skipping the step
- **WHEN** a new rider skips the notification step
- **THEN** no permission prompt appears, and notifications stay off

### Requirement: Notification settings
The rider SHALL be able to turn the daily notification on or off, set its time (default 06:30), and choose its days: days with ride windows in the active profile (the default), every day, or specific weekdays. When the active profile has no ride windows at all (the Anytime preset), the default SHALL be every day.

#### Scenario: Weekend rider default
- **WHEN** the active profile's only windows are on Saturday and Sunday and days are left at the default
- **THEN** notifications are delivered only on Saturday and Sunday

#### Scenario: Anytime rider default
- **WHEN** the active profile has no ride windows and days are left at the default
- **THEN** notifications are delivered every day

### Requirement: Notification content
Each notification SHALL state the verdict word for that day, for the active profile, at the background location source, using that day's radius override when one is set. For Ride, it SHALL list the ride windows that are clear. For Maybe and Nah, it SHALL give the most severe reason with its time, and the clear directions if there are any.

#### Scenario: Maybe morning
- **WHEN** units are imperial, the day's verdict is Maybe because of gusts up to 34 mph (55 km/h) to the west from 4 to 7 PM, and the south is clear
- **THEN** the notification states "Maybe" and names gusts, 34 mph, the west, 4–7 PM, and the south as clear

#### Scenario: Ride morning
- **WHEN** the day's verdict is Ride, with windows 7–9 AM and 4–6 PM
- **THEN** the notification states "Ride" and lists 7–9 AM and 4–6 PM as clear

### Requirement: Always scheduled ahead
The system SHALL keep notifications scheduled for the next 3 selected days at all times, using the newest forecast available. It SHALL rebuild every pending notification whenever a new forecast is fetched, or when the profile, location source, radius override or notification settings change.

#### Scenario: No background time granted
- **WHEN** iOS runs no background refresh overnight, and the app last fetched at 21:00 the previous evening
- **THEN** the 06:30 notification still arrives, built from the 21:00 forecast

#### Scenario: Settings change
- **WHEN** the rider moves the notification time from 06:30 to 05:45
- **THEN** all pending notifications are rescheduled for 05:45 with current content

### Requirement: Background refresh before delivery
The system SHALL ask iOS for a background refresh starting about 90 minutes before the next notification time. When it runs, it SHALL fetch under the background rules in `weather-data` and rebuild the pending notifications. Delivery SHALL NEVER depend on this refresh succeeding.

#### Scenario: Refresh runs in time
- **WHEN** the last fetch was more than 2 hours earlier and iOS grants a background refresh at 05:20 for a 06:30 notification
- **THEN** the notification is rebuilt from the 05:20 forecast

### Requirement: Honest forecast age
When the forecast behind a notification will be more than 3 hours old at delivery, the notification SHALL say when that forecast is from. When it will be more than 12 hours old at delivery, or no forecast covers the day, the notification SHALL NOT state a verdict and SHALL ask the rider to open the app for today's verdict.

#### Scenario: Last night's forecast
- **WHEN** a 06:30 notification is built from a 21:00 forecast (9.5 hours old at delivery)
- **THEN** it states the verdict and notes it's based on last night's forecast

#### Scenario: Too old
- **WHEN** a notification would be built from a forecast more than 12 hours old at delivery
- **THEN** it says to open the app for today's verdict and states no verdict

### Requirement: Opening from a notification
Tapping a ride notification SHALL open the app on the Today screen for that day.

#### Scenario: Tap
- **WHEN** the rider taps the morning notification
- **THEN** the app opens on Today, refreshing under the foreground rules
