import AppKit
import CoreGraphics
import os.log

/// Decides whether to open System Settings after an Accessibility / Screen
/// Recording / Input Monitoring request — without fighting macOS' own prompt.
///
/// The **first** request for each of these shows a system alert ("… would like
/// to …" · Open System Settings / Deny), shown by another process. Opening the pane
/// ourselves as well leaves that alert stranded on screen after the user grants
/// access in the pane, and the user has to close it by hand (or click a
/// confusing "Deny"). Later requests are silent, so there we *must* open the pane.
///
/// So after the request we briefly watch for a new window from another process
/// above the normal window layer. If one appears, that's the prompt: we leave the
/// pane to its "Open System Settings" button, which also dismisses it. If none
/// appears, we open the pane. Window IDs, layers, and owners come from
/// `CGWindowListCopyWindowInfo` and need no permission (only titles are gated).
@MainActor
enum SystemPromptWatch {

    struct WindowSample: Equatable {
        let id: CGWindowID
        let layer: Int
        let ownerPID: pid_t
    }

    private static let log = Logger(subsystem: "PermissionPilot", category: "systemPrompt")

    /// How long to wait for the prompt before concluding there isn't one.
    private static let detectWindow: TimeInterval = 1.0
    private static let pollInterval: TimeInterval = 0.2
    /// Stop tracking a prompt the user leaves open after this long.
    private static let maxPromptLifetime: TimeInterval = 300

    /// Takes the baseline snapshot. Call immediately **before** the request API.
    static func baseline() -> Set<CGWindowID> {
        Set(sample().map(\.id))
    }

    /// Opens `permission`'s pane unless a system prompt shows up within ~1 s.
    /// - Parameters:
    ///   - onPrompt: called once if a prompt is detected (pane left to it).
    ///   - onPromptGone: called once the detected prompt window is gone.
    static func openPaneUnlessPrompted(
        _ permission: Permission,
        baseline: Set<CGWindowID>,
        onPrompt: @escaping () -> Void,
        onPromptGone: @escaping () -> Void
    ) {
        let start = Date()
        func poll() {
            let prompt = promptWindows(baseline: baseline, current: sample(),
                                       ownPID: ProcessInfo.processInfo.processIdentifier,
                                       excludedPIDs: systemSettingsPIDs())
            if !prompt.isEmpty {
                log.notice("\(permission.rawValue, privacy: .public): macOS prompt detected (windows \(prompt.sorted(), privacy: .public)) — leaving the pane to it")
                onPrompt()
                watchUntilGone(prompt, since: start, then: onPromptGone)
            } else if Date().timeIntervalSince(start) >= detectWindow {
                log.notice("\(permission.rawValue, privacy: .public): no macOS prompt — opening the pane")
                SystemSettingsLink.open(permission)
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + pollInterval) { poll() }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + pollInterval) { poll() }
    }

    /// Pure decision: windows that appeared since `baseline`, belong to another
    /// process (not us, not System Settings), and sit above the normal layer —
    /// i.e. a system alert.
    nonisolated static func promptWindows(
        baseline: Set<CGWindowID>,
        current: [WindowSample],
        ownPID: pid_t,
        excludedPIDs: Set<pid_t>
    ) -> Set<CGWindowID> {
        Set(current
            .filter { !baseline.contains($0.id) && $0.layer > 0
                      && $0.ownerPID != ownPID && !excludedPIDs.contains($0.ownerPID) }
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
                  let layer = window[kCGWindowLayer as String] as? Int,
                  let pid = window[kCGWindowOwnerPID as String] as? pid_t
            else { return nil }
            return WindowSample(id: id, layer: layer, ownerPID: pid)
        }
    }

    private static func systemSettingsPIDs() -> Set<pid_t> {
        Set(NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.systempreferences")
            .map(\.processIdentifier))
    }
}
