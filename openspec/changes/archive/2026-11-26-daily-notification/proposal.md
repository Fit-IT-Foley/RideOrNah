# Proposal

## Why

The promise is "know before you gear up". Most riders won't open an app every morning, but they'll read a notification. With no server, the morning verdict has to be built and scheduled on the phone, and it has to stay honest when iOS doesn't give the app time to refresh in the background.

## What Changes

- Add an opt-in daily ride notification at a time the rider picks (default 06:30), on the days they choose: their ride-window days by default, every day, or specific weekdays.
- Fill it with the day's verdict and the main reason, or the clear windows, for the active profile at the background location source, including today's radius override.
- Always keep the next 3 notifications scheduled with the best forecast on hand, and rebuild them whenever a fresh forecast arrives or settings change. A notification still arrives even if iOS never runs a background refresh.
- Ask iOS for a background refresh shortly before the notification time, and mark older forecasts honestly in the notification text.
- Send "open the app" instead of a guess when no usable forecast exists.
- Tapping the notification opens the Today screen.
- Non-goals: push notifications (they'd need a server), change alerts during the day, and the calendar action (`calendar-suggestions`).

## Capabilities

### New Capabilities
- `ride-notifications`: notification permission, settings, scheduling, content and freshness rules for the daily ride notification.

### Modified Capabilities
- None.

## Impact

- App: notification settings screen, a scheduler that rebuilds pending notifications, and a `BGAppRefreshTask` handler.
- Privacy: adds notification permission. Content is built on the device. Nothing is sent anywhere.
- WeatherKit requests: background refreshes use the 2-hour background interval, adding at most about one refresh a day (1, 9 or 17 requests depending on radius) within the daily budget.
