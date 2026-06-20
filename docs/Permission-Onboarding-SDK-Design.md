# PermissionPilot — Design Doc
*A drop-in SwiftUI onboarding + permissions flow for locally-distributed macOS apps.*

**Status:** Draft · **Target:** native Swift/SwiftUI, macOS 12+ · **Distribution:** locally-distributed (non–App Store) apps · **License:** MIT (planned) · **Dependencies: zero third-party — Apple frameworks only.**

---

## 1. Problem
Locally-distributed macOS apps (DMG / Homebrew, not the Mac App Store) that need system permissions — Accessibility, Screen Recording, Input Monitoring, Full Disk Access, Camera, Microphone — cannot grant them programmatically. The user must flip toggles in System Settings. Today every such app reinvents detection, prompting, deep-linking, and onboarding UI, and most ship a poor first-run experience (or skip onboarding entirely).

## 2. Goal
A reusable, **zero-dependency** Swift/SwiftUI SDK that lets a developer declare the permissions their app needs and get, out of the box: a polished step-by-step first-run **onboarding flow** with permission setup woven in, live permission **detection**, **deep-links** to the exact System Settings pane, **auto re-check + auto-advance** when the user returns, and built-in handling of the well-known macOS gotchas.

**Non-goals:** Mac App Store / sandboxed apps (these permissions and deep-links are largely disallowed there); iOS; replacing Apple's consent UI (we route to it, never bypass it).

## 3. Scope — permissions covered
Accessibility, Screen Recording, Input Monitoring, Full Disk Access, Camera, Microphone. Optional / later: Automation (Apple Events), Notifications, Location, Bluetooth.

## 4. Dependency posture (decision)
**Zero third-party runtime dependencies.** Built entirely on Apple frameworks: ApplicationServices, CoreGraphics, AVFoundation, IOKit.hid, AppKit, SwiftUI.

- **PermissionFlow** and **FullDiskAccess** are **reference-only** — studied for approach (both MIT) and credited in the README where logic is informed by them, but **never imported**.
- **Rationale:** for a library meant to be adopted and grown, dependencies are a liability (version-coupling, supply-chain surface, adoption friction). "Zero dependencies — just add the package" is itself an adoption advantage. Everything those libraries provide is thin to reimplement on Apple APIs, and the non-trivial UI (drag-to-authorize, status rows) is exactly what we want to own and differentiate on.
- **Accepted tradeoff:** we own maintenance of the Full Disk Access heuristic and the System Settings deep-link anchors as macOS evolves. This maintenance is also the project's moat.

## 5. Landscape & differentiation
Only two valid macOS comparators:
- **PermissionFlow** (MIT, weeks-old): covers Accessibility / Screen Recording / Input Monitoring / Microphone / FDA / Bluetooth / Media; ships UI *components* (drag-to-authorize, status buttons) + deep-links. No full onboarding wizard, no auto-advance, Camera unclear, maturity risk.
- **FullDiskAccess** (MIT, stable, zero-dep): the single FDA permission only.
- Ruled out: MacPaw/PermissionsKit (Calendar/Contacts/Photos/FDA only — none of our system perms), debug45/PermissionWizard (macOS partial/TODO), PermissionsSwiftUI & sparrowcode/PermissionsKit (iOS-only / stale).

**Already present (we include, not skip):** detection, in-app prompts, deep-links, status rows, drag-to-authorize, coverage of the core permissions.
**Our differentiator (nobody ships):** full onboarding **wizard** + multi-permission **checklist** + **auto-recheck / auto-advance** + required/optional config + just-in-time priming + host-app theming + Camera/Automation coverage + baked-in edge-case handling — all **dependency-free** and **composable**.

## 6. Architecture (design-level)
Three layers, each usable independently — composability is a feature:
1. **Engine** (no UI): a declarative permission model + a manager that detects status, triggers prompts where possible, opens deep-links, and re-checks on app activation. Publishes live status for SwiftUI. For developers who want only the logic.
2. **Components:** per-permission status rows/buttons and a multi-permission **checklist** view. For developers who have their own onboarding.
3. **Flow:** a full first-run **wizard** (welcome → value/features → setup → permissions → done) with a step indicator, where the permission step *is* the checklist. For developers who want the whole experience.

**API shape (conceptual, not code):** the developer provides a list of required + optional permissions and optional copy/icon/theme overrides; the SDK supplies the manager, the checklist, and the wizard. Re-check is driven by `NSApplication.didBecomeActive` plus a light fallback poll.

## 7. Per-permission approach

| Permission | Detect | Request (in-app prompt?) | Deep-link anchor | Info.plist key |
|---|---|---|---|---|
| Accessibility | `AXIsProcessTrusted` | `AXIsProcessTrustedWithOptions` (prompt → Settings; manual toggle) | `Privacy_Accessibility` | `NSAccessibilityUsageDescription` (optional) |
| Screen Recording | `CGPreflightScreenCaptureAccess` | `CGRequestScreenCaptureAccess` (adds app + prompt) | `Privacy_ScreenCapture` | — |
| Input Monitoring | `IOHIDCheckAccess(listenEvent)` | `IOHIDRequestAccess(listenEvent)` | `Privacy_ListenEvent` | — |
| Camera | `AVCaptureDevice.authorizationStatus(.video)` | `requestAccess(.video)` (true prompt, once) | `Privacy_Camera` | `NSCameraUsageDescription` (required) |
| Microphone | `AVCaptureDevice.authorizationStatus(.audio)` | `requestAccess(.audio)` (true prompt, once) | `Privacy_Microphone` | `NSMicrophoneUsageDescription` (required) |
| Full Disk Access | heuristic read of a TCC-protected path (no API) | none — deep-link only | `Privacy_AllFiles` | — |

Deep-link form: `x-apple.systempreferences:com.apple.preference.security?<anchor>`; verify anchors per macOS version, with an `open` / AppleScript fallback.

## 8. Onboarding UX (the hybrid model)
- **Container:** multi-step wizard with a visible step indicator (~3–5 steps), in a centered window (~640–700 pt), Back/Continue bottom bar, Skip for optional steps, light/dark + reduce-motion support.
- **Permission step = live checklist:** one row per permission (SF Symbol + one-line "why" + status: green check / "Enable"). "Enable" deep-links to the exact pane; on return the row flips to ✓ and the wizard auto-advances. Show "N of M enabled."
- **Ordering:** required-first (with a benefit-framed primer), optional last and skippable; never block finishing onboarding on an optional grant.
- **Just-in-time:** optional capabilities (e.g., Camera/Mic) may be deferred to first use instead of the upfront checklist.
- **Re-entry:** keep a permanent permissions surface (Settings tab / menu-bar item) so users can return later.

**Visual reference:** approved tokens, screens, and metrics live in `PermissionPilot-Spec.md` (the canonical visual spec) and are embedded in the Claude Code build prompt.

## 9. Edge cases & gotchas (baked in)
- **Code-signing / TCC persistence:** grants are tied to code signature + bundle ID; ad-hoc / changing signatures lose grants on every rebuild. Guidance: sign with a stable Apple Development (dev) / Developer ID (distribution) identity, keep bundle ID + install path constant; `tccutil reset <Service> <bundleID>` to recover. The SDK surfaces clear states; it cannot fix signing — but the README must teach this (highest-value content).
- **Relaunch to finish:** some grants (Input Monitoring; pre-Sequoia Screen Recording) only take effect after quit & reopen → show a "Quit & Reopen" affordance.
- **Sequoia+ recurring Screen Recording prompt:** macOS re-prompts periodically (monthly); onboarding copy should pre-warn; no public entitlement to suppress.
- **Stale CGPreflight snapshot:** the screen-recording preflight value is captured at launch; re-verify (e.g., via SCShareableContent on 15+) rather than trusting a cached value mid-session.
- **Info.plist usage strings:** Camera/Mic require `NSCameraUsageDescription` / `NSMicrophoneUsageDescription` or the app crashes on first access.
- **No sandbox / notarize:** these apps are non-sandboxed; for smooth local distribution, Developer ID + notarization is effectively required (otherwise Gatekeeper friction + flaky TCC).

## 10. Open-source positioning
- **Gap:** no maintained, drop-in SwiftUI SDK that does multi-permission onboarding as a full flow. Real, recurring pain (window managers, screen tools, remote-support apps).
- **Moat:** the onboarding flow + the baked-in gotchas + staying current across macOS releases.
- **Adoption needs:** SPM, MIT, semantic versioning, a crisp declarative API, a polished README with a **demo GIF**, an **example app**, composable products (engine / components / flow), and a docs page on the code-signing gotcha.
- **Risk:** PermissionFlow is active; differentiate hard on full-flow + edge-cases + zero-deps + maintenance, or it could converge. Decision: build fresh (cleaner positioning) rather than contribute to PermissionFlow.

### Discoverability (set on the repo)
- **Name:** PermissionPilot
- **Description:** "Drop-in SwiftUI onboarding + permissions flow for macOS apps — Accessibility, Screen Recording, Full Disk Access, Input Monitoring. Zero dependencies."
- **GitHub topics:** `macos`, `swift`, `swiftui`, `permissions`, `permission-manager`, `tcc`, `accessibility`, `screen-recording`, `full-disk-access`, `onboarding`, `privacy`.

## 11. Roadmap (staged, with checkpoints)
1. **Signing groundwork** (docs + sample): stable signing so a grant survives ≥3 rebuilds. *Gate to proceed.*
2. **Engine:** declarative model + manager (detect / prompt / deep-link / recheck) for all six permissions. FDA heuristic ported from FullDiskAccess's approach (credited).
3. **Components:** status rows + multi-permission checklist with auto-advance.
4. **Flow:** full wizard + step indicator + skip/return; theming.
5. **Just-in-time** helpers for optional permissions.
6. **Harden:** Sequoia prompt, relaunch UX, stale-preflight, example app, README + demo GIF, notarization guide.

## 12. Open questions / decisions
- **Repo name** — PermissionPilot (decided).
- Minimum macOS version (12 vs 13).
- Whether to ship engine / components / flow as separate SPM products or one package with opt-in modules.
- Localization of permission copy.
