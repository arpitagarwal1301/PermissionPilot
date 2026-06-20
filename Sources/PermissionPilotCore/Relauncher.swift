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
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: url, configuration: configuration) { _, _ in
            DispatchQueue.main.async {
                NSApp.terminate(nil)
            }
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
