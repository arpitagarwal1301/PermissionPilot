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
