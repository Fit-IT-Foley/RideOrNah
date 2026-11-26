# Spec Delta

## MODIFIED Requirements

### Requirement: No backend and no data collection
The app SHALL work without any server operated by the developer. It SHALL NOT create user accounts, and SHALL NOT include analytics, advertising, attribution or crash-reporting code. Its only network destinations SHALL be Apple services (WeatherKit, the App Store and StoreKit, Apple Maps for place search and map display, and the user's own iCloud). Web pages, such as the privacy policy, SHALL open in Safari rather than inside the app.

#### Scenario: Network destinations
- **WHEN** the app is exercised through every feature while its network traffic is recorded
- **THEN** every request goes to an Apple-operated domain

#### Scenario: Privacy label
- **WHEN** the App Store privacy details are prepared
- **THEN** the app qualifies for "Data Not Collected" and "Data Not Used to Track You"
