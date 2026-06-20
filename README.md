# PermissionPilot

> ⚠️ **Scaffold placeholder.** The build brief (`docs/CLAUDE_CODE_BUILD_PROMPT.md`)
> refers to a canonical, already-written `README.md` that documents the public
> API — that file was **not** found in the repo. This stub exists only so the
> package layout is complete and `swift build` passes. Replace it with the
> canonical README (or confirm I should author one) before/at implementation.

A zero-dependency SwiftUI onboarding + permissions SDK for locally-distributed
(non–App Store) macOS apps — Accessibility, Screen Recording, Input Monitoring,
Full Disk Access, Camera, Microphone.

- **Zero third-party dependencies** — Apple frameworks only.
- **macOS 12+**, Swift 5.9+, SwiftUI + AppKit.
- Three composable products: `PermissionPilotCore` (engine), `PermissionPilotUI`
  (rows + checklist), `PermissionPilot` (full wizard).

## Status

Scaffold only. Implementation follows `docs/CLAUDE_CODE_BUILD_PROMPT.md` and the
design doc / visual spec in `docs/` + `design/`.

## License

MIT — see [LICENSE](LICENSE).
