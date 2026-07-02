import Foundation
import AppKit
import Security
import os.log

/// Quits and reopens the current app.
///
/// Some grants (Input Monitoring; pre-Sequoia Screen Recording) only take effect
/// after a relaunch. This launches a fresh instance and then terminates the
/// current one. Works for both bundled `.app`s and bare SPM executables.
enum Relauncher {
    @MainActor
    static func relaunch() {
        let bundleURL = Bundle.main.bundleURL
        if bundleURL.pathExtension == "app" {
            relaunchBundle(at: bundleURL)
        } else {
            relaunchExecutable()
        }
    }

    @MainActor
    private static func relaunchBundle(at url: URL) {
        if isSandboxed {
            relaunchBundleSandboxed(at: url)
            return
        }
        // Spawn a detached helper that waits for this instance to fully quit, then
        // reopens the app. We can't use NSWorkspace's `createsNewApplicationInstance`
        // because apps marked `LSMultipleInstancesProhibited` refuse a second
        // instance — it would terminate without ever relaunching.
        log.info("relaunching via detached shell helper (non-sandboxed): \(url.path, privacy: .public)")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", "sleep 1; /usr/bin/open \"\(url.path)\""]
        do {
            try process.run()
        } catch {
            log.error("shell helper failed to spawn: \(error, privacy: .public) — staying running")
            return
        }
        NSApp.terminate(nil)
    }

    /// False when this process has no way to relaunch itself: sandboxed apps
    /// can't spawn the detached shell helper, and if they also prohibit
    /// multiple instances the LaunchServices path (which briefly needs a
    /// second live instance) is closed too. UI should offer manual-restart
    /// guidance instead of a dead "Quit & Reopen" control.
    static var canRelaunch: Bool {
        !(isSandboxed && multipleInstancesProhibited)
    }

    /// The App Sandbox forbids spawning `/bin/sh`, so hand the launch to
    /// LaunchServices instead — it runs out of process, completing the launch
    /// even as this instance exits. This path needs a second live instance for
    /// a moment, so sandboxed apps marked `LSMultipleInstancesProhibited` can't
    /// relaunch at all; for them we stay running and the grant applies on the
    /// next manual restart.
    @MainActor
    private static func relaunchBundleSandboxed(at url: URL) {
        guard canRelaunch else {
            log.error("relaunch unavailable (sandboxed + LSMultipleInstancesProhibited) — staying running")
            return
        }
        log.info("relaunching via LaunchServices (sandboxed): \(url.path, privacy: .public)")
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        configuration.activates = true   // hand focus to the new instance
        NSWorkspace.shared.openApplication(at: url, configuration: configuration) { _, error in
            DispatchQueue.main.async {
                // Only quit once the relaunch is underway; on failure, stay
                // running rather than strand the user with no app at all.
                if let error {
                    log.error("LaunchServices relaunch failed: \(error, privacy: .public) — staying running")
                } else {
                    log.info("new instance underway — terminating this one")
                    NSApp.terminate(nil)
                }
            }
        }
    }

    /// Sandbox detection must read the entitlement from our own code
    /// signature: the `APP_SANDBOX_CONTAINER_ID` environment variable is NOT
    /// reliably present in sandboxed processes (observed absent in a sandboxed
    /// Xcode-built app), and misdetecting sends a sandboxed app down the
    /// shell-helper path — which quits without ever relaunching.
    private static var isSandboxed: Bool {
        if let task = SecTaskCreateFromSelf(nil),
           let value = SecTaskCopyValueForEntitlement(
               task, "com.apple.security.app-sandbox" as CFString, nil) {
            return (value as? Bool) == true
        }
        // Fallback heuristic: a sandboxed GUI app's home is its container.
        return NSHomeDirectory().contains("/Library/Containers/")
    }

    private static let log = Logger(subsystem: "PermissionPilot", category: "relaunch")

    /// Launch Services honors both boolean and string ("YES"/"true") plist
    /// values for its LS* keys, so read this one the same way.
    private static var multipleInstancesProhibited: Bool {
        switch Bundle.main.object(forInfoDictionaryKey: "LSMultipleInstancesProhibited") {
        case let flag as Bool:   flag
        case let text as String: (text as NSString).boolValue
        default:                 false
        }
    }

    @MainActor
    private static func relaunchExecutable() {
        let executableURL = URL(fileURLWithPath: ProcessInfo.processInfo.arguments[0])
        let process = Process()
        process.executableURL = executableURL
        process.arguments = Array(ProcessInfo.processInfo.arguments.dropFirst())
        try? process.run()
        NSApp.terminate(nil)
    }
}
