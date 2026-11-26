# Spec Delta

## Purpose

Defines where verdicts are evaluated: the rider's current or saved locations, how location permission is handled, the ride radius presets with a today-only override, and which location background features use.

## ADDED Requirements

### Requirement: Location permission
The system SHALL request only When-In-Use location permission, and SHALL request approximate accuracy by default. It SHALL NEVER request Always permission. Before the system prompt appears, the app SHALL explain that location is used only to fetch weather, and is sent only to Apple services, rounded: to Apple Weather for forecasts and, for saved places, to the rider's own iCloud. If permission is denied, the rider SHALL be able to continue with saved locations only.

#### Scenario: Permission denied
- **WHEN** the rider denies location permission during setup
- **THEN** setup asks them to add a saved location instead, and the app stays fully usable

#### Scenario: Approximate location
- **WHEN** the rider grants approximate location only
- **THEN** verdicts are evaluated at the reduced-accuracy location, rounded to 0.01°

### Requirement: Evaluation location choice
The rider SHALL be able to evaluate either their current location (when permission allows) or any saved location. The choice SHALL persist until the rider changes it. When no location is available (no permission and no saved locations), the system SHALL show no verdict and SHALL ask the rider to add a location.

#### Scenario: Checking work from home
- **WHEN** the rider selects the saved location "Work"
- **THEN** verdicts are evaluated around Work until they select another location

#### Scenario: No location at all
- **WHEN** location permission is denied and there are no saved locations
- **THEN** no verdict is shown, and the rider is asked to add a location

### Requirement: Saved locations
The rider SHALL be able to save up to 10 locations, each with a name. A location can be added by searching an address or place, by using the current location, or by placing a pin on a map. Saved locations SHALL be renamable and deletable. Stored coordinates SHALL be rounded to 0.01°.

#### Scenario: Adding Home by search
- **WHEN** the rider searches their street address and saves it as "Home"
- **THEN** "Home" appears in the location list, with coordinates rounded to 0.01°

#### Scenario: Limit reached
- **WHEN** 10 locations are saved
- **THEN** adding another is unavailable until one is deleted

### Requirement: Ride radius
The system SHALL offer the radius presets Local, 10 mi (16 km), 25 mi (40 km), 50 mi (80 km) and 100 mi (160 km). Each preset SHALL be stored as its kilometer value. Metric users see that value, and imperial users see it rounded to the nearest 5 mi, so switching units never changes the radius. Each profile SHALL have a default radius.

#### Scenario: Metric presets
- **WHEN** units are metric
- **THEN** the presets read Local, 16 km, 40 km, 80 km and 160 km

#### Scenario: Switching units keeps the radius
- **WHEN** the radius is 40 km and the rider switches units to imperial
- **THEN** the radius reads 25 mi and is still stored as 40 km

### Requirement: Today-only radius override
The rider SHALL be able to choose a different radius for today without changing the profile default. The override SHALL apply to every verdict, notification and widget for today, and SHALL reset to the profile default at local midnight.

#### Scenario: Long ride today
- **WHEN** the rider's default is 25 mi (40 km) and they set today's radius to 100 mi (160 km)
- **THEN** today's verdicts use 100 mi (160 km), and tomorrow's use 25 mi (40 km) again

#### Scenario: Midnight reset
- **WHEN** the local date changes
- **THEN** the override is cleared

### Requirement: Background location source
Notifications and widgets SHALL evaluate at the background location source, which the rider chooses: a specific saved location, or "where I last opened the app" (the last current location seen while the app was in the foreground). The default SHALL be a saved location named "Home" if one exists, and otherwise the last-seen location. The last-seen location SHALL be stored only on the device, rounded to 0.01°, and replaced each time a new location is seen.

#### Scenario: Default with Home saved
- **WHEN** a saved location named "Home" exists and the rider hasn't chosen a source
- **THEN** notifications and widgets evaluate at Home

#### Scenario: Last-seen location
- **WHEN** the source is "where I last opened the app" and the rider last opened the app downtown
- **THEN** notifications and widgets evaluate downtown until the app sees a new location

#### Scenario: No source available
- **WHEN** the source is "where I last opened the app" and no location has ever been seen
- **THEN** notifications and widgets ask the rider to open the app instead of showing a verdict
