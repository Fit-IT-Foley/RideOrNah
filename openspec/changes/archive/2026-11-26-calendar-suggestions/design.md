# Design

## Context

The engine already returns each day's opportunities (clear daylight stretches, longest first, at most three) and can evaluate any time range. The design canvas draws:
- the "Ride suggestions" toggle on the Alerts board,
- a suggestion pill under each Week row ("Clear 9 AM–4:45 PM" with Add to Calendar or Added),
- a "Ride suggestion" card on the Day detail board,
- the notification's Add to Calendar action on the Push board.

See proposal.md for motivation and the spec for behavior.

## Goals / Non-Goals

**Goals:**
- What's suggested, the event's contents, and warnings come from pure code in `Presentation`, tested on the Mac.
- No calendar permission, ever. Events are only added through the system editor.

**Non-Goals:**
- Writing, updating or deleting events after they're saved, and inviting people.

## Decisions

### Settings and records
- **The setting:** `Preferences.rideSuggestions` defaults to off, decodes tolerantly, and syncs like the other settings.
- **Added rides** (the range, the profile and place names, and the day) are kept by `PreferencesStore` in device-only defaults, next to `lastSeenLocation`. They're never synced, and they're pruned once their day has passed.

### `SuggestionPresenter` in `Presentation`
Given the outlook, whether suggestions are on, the added rides and now, it returns each day's suggestions: the range text ("11 AM–5:30 PM"), whether it's added, and the lower-confidence label. It returns none when:
- the setting is off,
- the forecast is more than 3 hours old (the day's freshness isn't fresh),
- or the day is Unknown.

An opportunity counts as added when an added ride has the same start and end.

### `CalendarDraft` in `Presentation`
`CalendarDraft` holds what the editor is pre-filled with:
- **Title:** "Ride · <profile name>".
- **Time and place:** the opportunity's start and end, and the evaluation place's name.
- **Notes:** "Clear at every point in 25 mi" (or "Clear here" for a local radius), "Forecast from 6:00 AM Mon 8 Jun", and "Check Ride or Nah before you leave."

### `AddedRideCheck` in `Presentation`
After each refresh, every added ride still ahead is re-evaluated with `VerdictEngine.evaluate(range:in:)` and the newest snapshot.
- **Maybe or Nah:** a notice such as "Your Saturday ride now looks like Nah: rain likely from 3 PM (80%)."
- **Unknown:** no notice. The ride is marked "Not checked".
- **Ride:** nothing.

Today shows the notices above the call. Week marks a not-checked ride's pill. The calendar is never touched.

### The editor
`CalendarEditor` wraps `EKEventEditViewController` with a fresh `EKEventStore`.
- From iOS 17, the editor runs out of process and needs no calendar permission or usage description.
- Its delegate reports saved or cancelled. Saved records the added ride, and cancelled changes nothing.
- In debug builds, `-calendarStub save|cancel` answers without the system editor, so UI tests can check both outcomes. One UI test still opens the real editor, to check that no permission prompt appears.

### The notification action
- **When it's attached:** `PlannedNotification` gains `calendarRange`. It's set only when suggestions are on, the day has an opportunity, and the forecast will be no more than 3 hours old at delivery. The planner uses the day's longest opportunity.
- **How it's delivered:** `LiveNotificationCenter` registers a `ride.calendar` category with a foreground "Add to Calendar" action, and puts the range in `userInfo`.
- **What it opens:** `NotificationRouter` opens Today and presents the editor pre-filled for that range.

### Screens
- **Alerts:** the tab gains the Ride suggestions card, per the board: "Suggest clear stretches. Adds them to the outlook, with Add to Calendar. We never read your calendar."
- **Week:** a pill under the row for each suggestion, in the board's style: an accent-tinted capsule, a calendar icon, "Clear <range>", and an Add to Calendar or Added button. The footer explains suggestions when they're on.
- **Day detail:** gains the "Ride suggestion" card from the board, one per opportunity.

## Risks / Trade-offs

- [The rider deletes or moves the event in Calendar] → The app can't know, so the record stays until its day passes. This is acceptable, since nothing reads the calendar.
- [Simulator calendars differ between iOS versions] → UI tests use the debug stub for saved and cancelled. One real-editor test checks only that it opens with no permission alert.

## Open Questions

- None.
