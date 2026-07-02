import Foundation
import AppKit

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
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", "sleep 1; /usr/bin/open \"\(url.path)\""]
        try? process.run()
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
        guard canRelaunch else { return }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: url, configuration: configuration) { _, error in
            DispatchQueue.main.async {
                // Only quit once the relaunch is underway; on failure, stay
                // running rather than strand the user with no app at all.
                if error == nil { NSApp.terminate(nil) }
            }
        }
    }

    private static var isSandboxed: Bool {
        ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] != nil
    }

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
