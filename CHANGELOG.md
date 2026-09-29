# Changelog

All notable changes to PermissionPilot are documented here. The format is based
on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.3.0] - 2026-09-29

### Fixed
- **Dragging the app icon into System Settings didn't work.** The helper's icon
  used SwiftUI `.onDrag { NSItemProvider(contentsOf:) }`, which presents the
  bundle as a *file promise* and allows only the copy operation — the privacy
  lists refuse that. It's now an AppKit drag source that writes the bundle's
  file URL with copy/link/generic, exactly like a Finder drag.
- **The helper vanished right when it was needed.** It was a transient popover,
  so it closed as soon as System Settings came forward; and every **Enable**
  click opened another one.
- **"Reveal in Finder" opened a new Finder window on every click.** It now brings
  Finder forward while a window it opened is still on screen, and only reveals
  afresh once that window is closed (no Automation permission needed).

- **macOS' first-time prompt was left stranded on screen.** The first request
  for Accessibility / Screen Recording / Input Monitoring shows a system alert
  (Open System Settings / Deny); opening the pane at the same time left that
  alert behind after the user granted access. Requests now watch briefly for
  that prompt and, if it appears, leave the pane to its button (which also
  dismisses it); the helper points the user at it. Later, silent requests still
  open the pane.

### Added
- `PermissionManager.systemPromptShowing` — the permission whose macOS prompt
  is currently on screen, if any.
- `ManualAddHelper` — one shared, floating, non-activating panel for the
  manual-add permissions (Accessibility, Screen Recording, Input Monitoring,
  Full Disk Access). It stays above System Settings, docks beside its window,
  switches content in place when another permission's **Enable** is clicked,
  and confirms + closes itself once the permission is granted. `PermissionRow`
  / `PermissionTile` use it automatically; hosts with their own UI can call
  `ManualAddHelper.show(manager:permission:…)`. `OnboardingPresenter` closes it
  with the wizard.

### Changed
- **Enable** on Accessibility, Screen Recording, and Input Monitoring now calls
  `request(_:)` before showing the helper, which adds the app to the list
  (switched off) and opens the pane — the user usually just flips the switch,
  and dragging becomes the fallback. The helper's copy says so.

## [0.2.0] - 2026-07-02

First release hardened by a real sandboxed consumer (integration-tested inside a
sandboxed menu-bar app).

### Added
- `OnboardingPresenter.front()` — deminiaturizes and re-fronts an already-presented
  wizard. Hosts that keep a weak presenter reference should call this instead of
  `NSApp.activate`, which neither deminiaturizes nor reorders an existing window.
- `PermissionManager.relaunchAvailable` — false when the host has no way to
  relaunch itself (sandboxed + `LSMultipleInstancesProhibited`). The
  `PermissionsView` relaunch banner now hides its "Quit & Reopen" button in that
  case (the banner copy already instructs a manual quit-and-reopen), instead of
  rendering a button that silently does nothing.
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
- Regression tests for the relaunch decisions (sandbox detection via injected
  entitlement value, `LSMultipleInstancesProhibited` plist forms, the
  can-relaunch matrix).

### Fixed
- **"Open the … list" always opens the pane.** The manual-add walkthrough's
  step-1 button called `request()`, which for Accessibility maps to the AX
  prompt — shown by macOS only once per app, so every later click was a silent
  no-op. The button now deep-links to the pane; the Accessibility *request*
  path also falls back to opening the pane when the one-shot prompt is spent
  (mirroring the Screen Recording behavior).
- **Wizard visible after relaunch.** The onboarding window now calls
  `orderFrontRegardless()` — cooperative activation (macOS 14+) can deny
  activation right after a quit-and-reopen handoff, which could leave the
  relaunched wizard buried.
- **Sandbox-safe relaunch.** `PermissionManager.quitAndReopen()` previously spawned
  a detached `/bin/sh` helper, which the App Sandbox forbids — in a sandboxed app
  the relaunch never happened and the app just quit. Sandboxed apps now relaunch
  via LaunchServices (`NSWorkspace.openApplication` with
  `createsNewApplicationInstance`), terminating only once the new instance is
  underway. Sandboxed apps marked `LSMultipleInstancesProhibited` (which refuse a
  second live instance) stay running instead of quitting into nothing; the grant
  applies on the next manual restart. Non-sandboxed behavior is unchanged.
  Sandbox detection reads the `com.apple.security.app-sandbox` entitlement from
  the process's own code signature (`SecTaskCopyValueForEntitlement`) — the
  `APP_SANDBOX_CONTAINER_ID` environment variable is not reliably present, and
  misdetecting sent sandboxed apps down the shell path (quit, no relaunch).
  All relaunch paths now log to os.log (subsystem `PermissionPilot`, category
  `relaunch`) so a failed relaunch is diagnosable via `log show`.
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

[Unreleased]: https://github.com/arpitagarwal1301/PermissionPilot/compare/v0.3.0...HEAD
[0.3.0]: https://github.com/arpitagarwal1301/PermissionPilot/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/arpitagarwal1301/PermissionPilot/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/arpitagarwal1301/PermissionPilot/releases/tag/v0.1.0
