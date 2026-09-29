import AppKit
import CoreGraphics
import os.log

/// Decides whether to open System Settings after an Accessibility / Screen
/// Recording / Input Monitoring request — without fighting macOS' own prompt.
///
/// A request can make macOS show its own alert ("… would like to …" · Open
/// System Settings / Deny), drawn by another process. Opening the pane ourselves
/// as well leaves that alert stranded on screen after the user grants access in
/// the pane, and the user has to close it by hand (or click a confusing "Deny").
/// When no alert appears we *must* open the pane, or Enable does nothing.
///
/// So after the request we briefly watch for that alert: a window owned by a
/// known prompt host (`universalAccessAuthWarn`, `UserNotificationCenter`) that
/// wasn't on screen before the request. Matching the **owner** is what works:
/// on macOS 27 the alert sits at the normal window layer (so "raised window"
/// checks miss it), and requests can trigger a Spaces switch that brings dozens
/// of unrelated windows, menu bars included, on screen at once (so "any new
/// window" checks misfire). If the alert appears we leave the pane to its "Open
/// System Settings" button, which also dismisses it; if not, we open the pane.
/// Window IDs and owner names come from `CGWindowListCopyWindowInfo` and need
/// no permission (only titles are gated).
///
/// When a prompt is *likely* (see ``PermissionProbe``) we wait longer before
/// concluding there isn't one, since opening the pane under a slow prompt is
/// the failure that strands it.
@MainActor
enum SystemPromptWatch {

    struct WindowSample: Equatable {
        let id: CGWindowID
        let layer: Int
        let ownerName: String
    }

    /// Processes that draw TCC's consent alerts (verified on macOS 27: Screen
    /// Recording and Input Monitoring alerts come from `universalAccessAuthWarn`).
    nonisolated static let promptHosts: Set<String> = ["universalAccessAuthWarn", "UserNotificationCenter"]

    private static let log = Logger(subsystem: "PermissionPilot", category: "systemPrompt")

    private static let pollInterval: TimeInterval = 0.2
    /// Stop tracking a prompt the user leaves open after this long.
    private static let maxPromptLifetime: TimeInterval = 300

    /// How long to wait for the prompt before concluding there isn't one.
    nonisolated static func detectWindow(promptLikely: Bool) -> TimeInterval {
        promptLikely ? 3.0 : 1.0
    }

    /// Takes the baseline snapshot. Call immediately **before** the request API.
    static func baseline() -> Set<CGWindowID> {
        Set(sample().map(\.id))
    }

    /// Opens `permission`'s pane unless a system prompt shows up first.
    /// - Parameters:
    ///   - promptLikely: macOS is expected to prompt — wait longer for it.
    ///   - onPrompt: called once if a prompt is detected (pane left to it).
    ///   - onPromptGone: called once the detected prompt window is gone.
    static func openPaneUnlessPrompted(
        _ permission: Permission,
        baseline: Set<CGWindowID>,
        promptLikely: Bool,
        onPrompt: @escaping () -> Void,
        onPromptGone: @escaping () -> Void
    ) {
        let start = Date()
        let timeout = detectWindow(promptLikely: promptLikely)
        func poll() {
            let current = sample()
            let prompt = promptWindows(baseline: baseline, current: current)
            let elapsed = Date().timeIntervalSince(start)
            if !prompt.isEmpty {
                log.notice("\(permission.rawValue, privacy: .public): macOS prompt detected after \(elapsed, format: .fixed(precision: 2), privacy: .public)s (windows \(prompt.sorted(), privacy: .public)) — leaving the pane to it")
                onPrompt()
                watchUntilGone(prompt, since: start, then: onPromptGone)
            } else if elapsed >= timeout {
                let appeared = current.filter { !baseline.contains($0.id) }
                    .map { "\($0.ownerName)#\($0.id)@L\($0.layer)" }
                log.notice("\(permission.rawValue, privacy: .public): no macOS prompt within \(timeout, privacy: .public)s (likely: \(promptLikely, privacy: .public); new windows: \(appeared, privacy: .public)) — opening the pane")
                SystemSettingsLink.open(permission)
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + pollInterval) { poll() }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + pollInterval) { poll() }
    }

    /// Pure decision: prompt-host windows that came on screen since `baseline`.
    nonisolated static func promptWindows(
        baseline: Set<CGWindowID>,
        current: [WindowSample]
    ) -> Set<CGWindowID> {
        Set(current
            .filter { !baseline.contains($0.id) && promptHosts.contains($0.ownerName) }
            .map(\.id))
    }

    private static func watchUntilGone(_ ids: Set<CGWindowID>, since start: Date,
                                       then onGone: @escaping () -> Void) {
        let onScreen = Set(sample().map(\.id))
        if ids.isDisjoint(with: onScreen) || Date().timeIntervalSince(start) > maxPromptLifetime {
            onGone()
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            watchUntilGone(ids, since: start, then: onGone)
        }
    }

    private static func sample() -> [WindowSample] {
        guard let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements],
                                                    kCGNullWindowID) as? [[String: Any]]
        else { return [] }
        return info.compactMap { window in
            guard let id = window[kCGWindowNumber as String] as? CGWindowID,
                  let layer = window[kCGWindowLayer as String] as? Int
            else { return nil }
            return WindowSample(id: id, layer: layer,
                                ownerName: window[kCGWindowOwnerName as String] as? String ?? "")
        }
    }
}
