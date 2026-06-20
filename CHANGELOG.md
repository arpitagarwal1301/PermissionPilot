# Changelog

All notable changes to PermissionPilot are documented here. The format is based
on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **Wizard customization** via `OnboardingConfiguration`: `showsWelcomeStep` and
  `showsDoneStep` to omit the intro / "all set" screens (e.g. when the host has
  its own onboarding and wants only the permissions step), and `colorScheme` to
  pin light/dark (default `nil` follows the system theme).
- **Localization.** Every user-facing string now routes through the localization
  system with stable keys and an English base; the SDK is fully translatable
  (ships English only — add a `<lang>.lproj/Localizable.strings` per target to
  contribute a language). See [CONTRIBUTING.md](CONTRIBUTING.md).
- **CI** — GitHub Actions builds and tests on macOS for every push and PR.
- `CHANGELOG.md` and `CONTRIBUTING.md`.

### Fixed
- Demo build script now copies the SwiftPM resource bundles into the `.app`, so
  `Bundle.module` (localizations) resolves at runtime.
- `EKAuthorizationStatus` mapping no longer emits a "switch must be exhaustive"
  warning (mapped on stable raw values).

## [0.1.0] - 2026-06-20

Initial release.

### Added
- **16 macOS permissions** across three tiers:
  - **Prompt-based** — Camera, Microphone, Location, Contacts, Calendars,
    Reminders, Photos, Speech Recognition, Bluetooth, Notifications, plus the
    system-prompt panes (Accessibility, Screen Recording, Input Monitoring).
  - **Deep-link-only** — Full Disk Access, Automation, Local Network.
- `PermissionManager` engine: live detection, request/prompt, System Settings
  deep-links, auto re-check on activation, and relaunch handling.
- Components: `PermissionRow`, `PermissionTile`, `PermissionChecklist`,
  `PermissionsView` (List ⇄ Grid), `JustInTimePermissionButton`,
  `DragToAuthorizeView`.
- `OnboardingView` wizard (welcome → permissions → done) with theming and host
  copy/icon/accent overrides — no SDK branding of its own.
- Three composable products (`PermissionPilotCore`, `PermissionPilotUI`,
  `PermissionPilot`); **zero third-party dependencies**.

[Unreleased]: https://github.com/arpitagarwal1301/PermissionPilot/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/arpitagarwal1301/PermissionPilot/releases/tag/v0.1.0
