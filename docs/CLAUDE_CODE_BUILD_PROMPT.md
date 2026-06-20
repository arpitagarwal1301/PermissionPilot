# Build prompt for Claude Code — PermissionPilot

Paste this into Claude Code with `Permission-Onboarding-SDK-Design.md` and `README.md` present in the repo as context.

---

Build **PermissionPilot**, a drop-in SwiftUI onboarding + permissions SDK for locally-distributed (non–App Store) macOS apps. Use `Permission-Onboarding-SDK-Design.md` as the authoritative spec and `README.md` as the canonical public README — match the API it documents, and don't rewrite the README's intent.

## Hard constraints
- **Zero third-party dependencies.** Apple frameworks only: Foundation, AppKit, SwiftUI, ApplicationServices, CoreGraphics, AVFoundation, IOKit.hid.
- Target macOS 12+, Swift 5.9+, Swift Package Manager.
- SwiftUI with AppKit interop where needed (NSWorkspace, NSApplication notifications, NSWindow / NSHostingController).
- Non-sandboxed assumptions; do not add the App Sandbox capability.

## Package layout (composable)
One SPM package `PermissionPilot` exposing three products (or one product with clearly separated modules):
1. `PermissionPilotCore` — engine, no UI.
2. `PermissionPilotUI` — status rows + checklist (depends on Core).
3. `PermissionPilot` — full onboarding wizard (depends on Core + UI).

## Engine (Core)
- `enum Permission`: accessibility, screenRecording, inputMonitoring, fullDiskAccess, camera, microphone.
- `enum PermissionStatus`: granted, denied, notDetermined, unknown.
- Per-permission detect + request + Settings deep-link per the design doc's table:
  - Accessibility: `AXIsProcessTrusted` / `AXIsProcessTrustedWithOptions`
  - Screen Recording: `CGPreflightScreenCaptureAccess` / `CGRequestScreenCaptureAccess`
  - Input Monitoring: `IOHIDCheckAccess` / `IOHIDRequestAccess` (`kIOHIDRequestTypeListenEvent`)
  - Camera / Microphone: `AVCaptureDevice.authorizationStatus` / `requestAccess`
  - Full Disk Access: heuristic read of a TCC-protected path (no API); deep-link only. Credit the FullDiskAccess approach in code comments.
- Deep-links via `x-apple.systempreferences:com.apple.preference.security?<anchor>` opened with NSWorkspace; provide an `open` / AppleScript fallback.
- An `@MainActor` `ObservableObject` manager that publishes live `[Permission: PermissionStatus]`, with `refresh()`, re-check on `NSApplication.didBecomeActiveNotification` plus a light timer fallback, a `request(_:)` that prompts where possible else deep-links, and `allRequiredGranted`.
- Declarative init: `init(required:optional:infoOverrides:)`.

## Components (UI)
- A per-permission row: SF Symbol + title + one-line description + status (✓ / Enable / Open Settings).
- A multi-permission checklist that flips rows to ✓ on grant and reports "N of M enabled"; required vs optional handling; plus a just-in-time helper to request a single permission at point of use.
- Light/dark, reduce-motion, VoiceOver labels; never convey status by color alone.

## Flow
- A full first-run wizard: welcome → value/features → setup → permissions (the checklist) → done, with a step indicator, Back/Continue, Skip for optional steps, centered window (~640–700 pt). Auto-advance the permissions step once all required are granted; show a "Quit & Reopen" affordance where a relaunch is required (Input Monitoring; pre-Sequoia Screen Recording).
- Persist completion (e.g. `@AppStorage`) and allow re-opening the flow from settings.

## Edge cases to implement / surface
- Stale `CGPreflight` snapshot — re-verify rather than trusting a cached value.
- macOS Sequoia recurring Screen Recording prompt — include a short pre-warning in copy.
- Camera / Microphone require `NSCameraUsageDescription` / `NSMicrophoneUsageDescription` — document in README/example and fail gracefully.
- Surface signing-persistence states clearly, but do not attempt to fix signing.

## Also produce
- An **example app** demonstrating the full wizard with 3–4 permissions.
- Unit tests where reasonable (status mapping, deep-link URL building, required-granted logic).
- Inline doc comments; keep the public API matching the README.
- Ensure it builds on macOS 12+ in Xcode 15+.

Do not add any external package.

## Visual spec (match the approved design)
Match the UI to `PermissionPilot-Spec.md` (in the repo) and the attached light/dark screenshots — that spec + the screenshots are the canonical visual target.

**Implement native, don't hard-code.** The hex values in the spec are the *reference the system produces*; build with **system semantic colors** so the UI adapts to dark mode, increase-contrast, and the user's accent automatically:
- Window bg → `NSColor.windowBackgroundColor`; card/control → `NSColor.controlBackgroundColor`; primary text → `.labelColor`; secondary text → `.secondaryLabelColor`; separators → `.separatorColor`.
- Primary buttons / tint → `Color.accentColor` (follows the user's/host's accent); default to the system accent and allow a host override — do **not** hard-code `#007AFF`.
- "Granted" check + label → `NSColor.systemGreen`; green is reserved for the granted state only.
- Use a **real titled `NSWindow`** for the wizard — do not draw fake traffic lights (the mockup shows them, but real window chrome provides them).
- Row icons via **SF Symbols**: `accessibility`, `display` (or `rectangle.dashed.badge.record`), `internaldrive`/`externaldrive`, `keyboard`.
- Prefer **semantic SwiftUI text styles** (`.title2`, `.headline`, `.callout`, `.subheadline`) near the spec's sizes/weights rather than fixed point sizes.

**Three screens** (light + dark, per screenshots):
1. **Welcome — host-branded.** App-icon slot (host image; neutral placeholder if none), headline "Welcome to {appName}", host subtitle, primary "Get Started". The SDK ships **no branding of its own**.
2. **Permissions — checklist.** Step dots; card "Permissions needed"; "N of M enabled" header; rows = icon tile + SF Symbol, bold name + host-overridable one-line reason, trailing state (green ✓ "Granted" or blue "Enable"); footer Back (secondary) / Continue (primary, disabled until all *required* granted).
3. **Done.** Green success check, "You're all set", host subtitle, "Finish".

**Host-customization API (the contract behind the spec):** `appName`, `appIcon`, welcome `headline`/`subtitle`, done `subtitle`, per-permission **reason** overrides, and an optional accent **tint** — all with sensible defaults.

Default metrics from the spec (window 700×540, card 640 wide, row 64, icon tile 40, radii 11/12/9, spacing scale 4·8·12·16·20·24·32) are good starting values; let SwiftUI layout adapt.
