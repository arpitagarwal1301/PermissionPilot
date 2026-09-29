import AppKit
import CoreGraphics

/// "Reveal in Finder" that doesn't pile up windows.
///
/// `NSWorkspace.activateFileViewerSelecting` opens a **new** Finder window on
/// every call, so a user clicking Reveal once per permission ends up with a
/// stack of identical windows. Instead we remember which Finder windows our
/// reveal opened; while any of them is still on screen, a repeat click just
/// brings Finder forward. Once they're all closed, the next click reveals again.
///
/// Window IDs, owners, and layers come from `CGWindowListCopyWindowInfo`, which
/// needs no permission (only window *titles* are Screen Recording–gated) —
/// scripting Finder instead would cost the user an extra Automation prompt.
@MainActor
enum FinderReveal {
    private static let finderBundleID = "com.apple.finder"
    /// Finder windows opened by our reveals and not yet seen closed.
    private static var trackedWindowIDs: Set<CGWindowID> = []

    static func reveal(_ url: URL) {
        let onScreen = finderWindowIDs()
        if shouldRefront(tracked: trackedWindowIDs, onScreen: onScreen), refrontFinder() {
            return
        }
        trackedWindowIDs.removeAll()
        NSWorkspace.shared.activateFileViewerSelecting([url])
        // Finder opens the window asynchronously; attribute whatever appears
        // shortly after the reveal to it.
        for delay in [0.4, 1.2] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                trackedWindowIDs.formUnion(finderWindowIDs().subtracting(onScreen))
            }
        }
    }

    /// Pure decision: re-front Finder only while a window our reveal opened is
    /// still on screen; otherwise reveal afresh.
    nonisolated static func shouldRefront(tracked: Set<CGWindowID>, onScreen: Set<CGWindowID>) -> Bool {
        !tracked.isDisjoint(with: onScreen)
    }

    /// On-screen, normal-layer Finder windows (the desktop is excluded).
    private static func finderWindowIDs() -> Set<CGWindowID> {
        let pids = Set(NSRunningApplication.runningApplications(withBundleIdentifier: finderBundleID)
            .map(\.processIdentifier))
        guard !pids.isEmpty,
              let info = CGWindowListCopyWindowInfo(
                  [.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID
              ) as? [[String: Any]]
        else { return [] }
        var ids: Set<CGWindowID> = []
        for window in info {
            guard let pid = window[kCGWindowOwnerPID as String] as? pid_t, pids.contains(pid),
                  (window[kCGWindowLayer as String] as? Int) == 0,
                  let number = window[kCGWindowNumber as String] as? CGWindowID
            else { continue }
            ids.insert(number)
        }
        return ids
    }

    /// Activates Finder through LaunchServices, which works even when the
    /// caller isn't frontmost (unlike `NSRunningApplication.activate` under
    /// macOS 14's cooperative activation). False if Finder can't be located.
    private static func refrontFinder() -> Bool {
        guard let finderURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: finderBundleID)
        else { return false }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.openApplication(at: finderURL, configuration: configuration)
        return true
    }
}
