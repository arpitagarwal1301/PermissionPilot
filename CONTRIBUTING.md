# Contributing to PermissionPilot

Thanks for your interest! PermissionPilot is a small, focused SDK — contributions
that keep it that way are very welcome.

## Build & test

```bash
swift build
swift test
```

CI runs both on macOS for every PR. To exercise the UI, build and run the signed
demo app (it gets its own TCC identity — required for permission toggles to work):

```bash
Example/build-demo-app.sh --open
```

> Permission **prompts** only appear for a properly signed app with its own TCC
> identity, and may be suppressed on MDM-managed Macs. Test prompt-based
> permissions on a personal/unmanaged Mac.

## Ground rules

- **Zero third-party dependencies.** Apple frameworks only — this is a hard
  constraint.
- **macOS 12+.** Guard newer APIs with `if #available`.
- **No SDK branding.** Every visible string, icon, and accent comes from the host
  app, each with a sensible default.
- Match the surrounding style; keep public APIs documented.
- Status is never conveyed by color alone (accessibility); keep VoiceOver labels
  meaningful.

## Adding a translation

The SDK is fully localized with an English base. To add a language, drop a
`Localizable.strings` for it into **each** target's resources, mirroring the keys
in the English base:

- `Sources/PermissionPilotCore/Resources/<lang>.lproj/Localizable.strings`
- `Sources/PermissionPilotUI/Resources/<lang>.lproj/Localizable.strings`
- `Sources/PermissionPilot/Resources/<lang>.lproj/Localizable.strings`

Copy each `en.lproj/Localizable.strings`, translate the values (keep the keys and
any `%@` / `%1$lld` format specifiers unchanged), and open a PR. No code changes
are needed — `Bundle.module` picks up the new locale automatically.

## Pull requests

1. Branch from `main`.
2. Keep changes focused; update `CHANGELOG.md` under **Unreleased**.
3. Ensure `swift build` and `swift test` pass.
4. Open the PR against `main`.
