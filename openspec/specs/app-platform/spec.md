# app-platform Specification

## Purpose

Defines the platform baseline every RideOrNah feature inherits: supported OS versions, the on-device and no-data-collection guarantees, Liquid Glass appearance, and baseline accessibility.

## Requirements

### Requirement: Supported platforms
The app SHALL install and run on iPhone with iOS 26.0 or later. It SHALL NOT require any feature that is unavailable on iOS 26.0 to deliver its core functionality.

#### Scenario: Install on the oldest supported OS
- **WHEN** the app is installed on an iPhone running iOS 26.0
- **THEN** it launches and every feature works as it does on newer iOS versions

#### Scenario: Unsupported OS
- **WHEN** a user on iOS 18 views the app in the App Store
- **THEN** the App Store reports the app as requiring iOS 26.0 or later

### Requirement: Liquid Glass appearance
The app SHALL render its surfaces and system controls with Liquid Glass on every supported iOS version.

#### Scenario: Any supported OS
- **WHEN** the app runs on any supported iOS version
- **THEN** its surfaces and system controls use Liquid Glass

### Requirement: No backend and no data collection
The app SHALL work without any server operated by the developer. It SHALL NOT create user accounts, and SHALL NOT include analytics, advertising, attribution or crash-reporting code. Its only network destinations SHALL be Apple services (WeatherKit, the App Store and StoreKit, and the user's own iCloud).

#### Scenario: Network destinations
- **WHEN** the app is exercised through every feature while its network traffic is recorded
- **THEN** every request goes to an Apple-operated domain

#### Scenario: Privacy label
- **WHEN** the App Store privacy details are prepared
- **THEN** the app qualifies for "Data Not Collected" and "Data Not Used to Track You"

### Requirement: Privacy manifest
The app bundle SHALL include a privacy manifest that declares no tracking, no tracking domains and no collected data types. It SHALL declare an approved reason for each required-reason API the app uses.

#### Scenario: Manifest present in build
- **WHEN** a release build of the app is produced
- **THEN** the bundle contains a privacy manifest with tracking disabled and an empty collected-data list

### Requirement: Baseline accessibility
Every screen SHALL support Dynamic Type up to the largest accessibility size without truncating essential information. Every screen SHALL be fully operable with VoiceOver. Any state shown with color, including verdicts, SHALL also be conveyed in text or an accessibility label.

#### Scenario: Largest text size
- **WHEN** the user sets the largest accessibility text size
- **THEN** every screen's essential information is readable without truncation, scrolling if needed

#### Scenario: Color-independent state
- **WHEN** VoiceOver focuses an element whose state is shown by color
- **THEN** VoiceOver reads the state in words

### Requirement: Light and dark appearance
The app SHALL follow the system light or dark appearance setting and update when it changes, without restarting.

#### Scenario: Switching appearance
- **WHEN** the user switches the system from light to dark mode while the app is open
- **THEN** the app updates to the dark appearance immediately
