# Changelog

All notable changes to PermissionPilot are documented here. The format is based
on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **README visuals** — an animated light/dark wizard-flow GIF (shown side by
  side) and a theme-aware 16-permission board grid. `SnapshotMode` now renders
  the board in both themes for regenerable assets.
- **Downloadable demo** — universal, ad-hoc-signed installers attached to the
  GitHub release so devs can evaluate without building: a `.pkg` (recommended —
  `Example/make-pkg.sh`; the installed app opens clean, no per-launch prompt) and
  a `.dmg` (`Example/make-dmg.sh`). Neither is notarized; each needs a one-time
  GUI approval (right-click → Open / System Settings → Open Anyway).
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

### Added (hosting API)
- `OnboardingPresenter.front()` — deminiaturizes and re-fronts an already-presented
  wizard. Hosts that keep a weak presenter reference should call this instead of
  `NSApp.activate`, which neither deminiaturizes nor reorders an existing window.
- `PermissionManager.relaunchAvailable` — false when the host has no way to
  relaunch itself (sandboxed + `LSMultipleInstancesProhibited`). The
  `PermissionsView` relaunch banner now hides its "Quit & Reopen" button in that
  case (the banner copy already instructs a manual quit-and-reopen), instead of
  rendering a button that silently does nothing.

### Fixed
- **Sandbox-safe relaunch.** `PermissionManager.quitAndReopen()` previously spawned
  a detached `/bin/sh` helper, which the App Sandbox forbids — in a sandboxed app
  the relaunch never happened and the app just quit. Sandboxed apps now relaunch
  via LaunchServices (`NSWorkspace.openApplication` with
  `createsNewApplicationInstance`), terminating only once the new instance is
  underway. Sandboxed apps marked `LSMultipleInstancesProhibited` (which refuse a
  second live instance) stay running instead of quitting into nothing; the grant
  applies on the next manual restart. Non-sandboxed behavior is unchanged.
- **Docs:** corrected the App Sandbox guidance. The engine/detection work
  sandboxed, and the standard privacy permissions are usable with the matching
  entitlements; only Accessibility, Input Monitoring, Full Disk Access, and
  Automation are sandbox-incompatible (was an over-broad "non-sandboxed only").
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
