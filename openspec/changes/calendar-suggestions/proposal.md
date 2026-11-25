# Proposal

## Why

Riders asked to opt in to calendar invites for the times they can ride. The engine already finds ride opportunities across the week. Putting them a tap away from the rider's calendar turns "good weather Saturday" into a planned ride, without the app ever reading the rider's calendar.

## What Changes

- Add an opt-in "Ride suggestions" setting, off by default.
- When it's on, show up to three ride opportunities per day across the 7-day outlook, each with an "Add to Calendar" action.
- Adding opens the system event editor, pre-filled with a title, time, location and forecast notes. The rider confirms, edits or cancels. No calendar permission is requested, and the app never reads or changes the calendar.
- Remember on the device which suggestions the rider added, to avoid duplicates, and warn in the app if the forecast for an added ride turns bad.
- Add an "Add to Calendar" action to the daily notification when today has an opportunity.
- Non-goals: automatic calendar writing, updating or deleting events after they're added, and inviting other people.

## Capabilities

### New Capabilities
- `ride-calendar`: the opt-in setting, how suggestions are shown and added through the system editor, duplicate tracking, forecast-change warnings, and the notification action.

### Modified Capabilities
- None. The notification action is specified in `ride-calendar` and built on the notification scheduler from `daily-notification`.

## Impact

- App: settings toggle, suggestion rows in the outlook and day detail, a system event-editor presenter, and a notification category with an action.
- Privacy: no calendar permission. The system editor runs out of process, and we only learn whether the rider saved or cancelled. Added-suggestion records stay on the device and are deleted once their day passes.
- WeatherKit requests: none. Suggestions reuse the outlook's forecasts.
