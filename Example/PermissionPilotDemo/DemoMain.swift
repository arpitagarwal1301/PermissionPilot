// PermissionPilotDemo — entry point.
//
// A bare AppKit entry (rather than a SwiftUI `@main App`) so the demo runs
// reliably as an unbundled SPM executable via `swift run PermissionPilotDemo`,
// with a real Dock presence and menu. The async `main()` hops onto the main
// actor before constructing the (@MainActor) app delegate.

import AppKit
import PermissionPilot

@main
struct DemoMain {
    static func main() async {
        let args = CommandLine.arguments
        // Headless asset generation: render the wizard screens to PNGs and exit.
        if let i = args.firstIndex(of: "--snapshot") {
            let outDir = (i + 1 < args.count) ? args[i + 1] : "/tmp/pp_snaps"
            await MainActor.run { SnapshotMode.run(outDir: outDir) }
            return
        }
        // Headless diagnostic: detect each permission once, write to a file, exit.
        if let i = args.firstIndex(of: "--check") {
            let outFile = (i + 1 < args.count) ? args[i + 1] : "/tmp/pp_check.txt"
            await MainActor.run {
                _ = NSApplication.shared
                let mgr = PermissionManager(
                    required: [.accessibility, .screenRecording, .inputMonitoring],
                    optional: [.fullDiskAccess]
                )
                var lines = ["bundleId=\(Bundle.main.bundleIdentifier ?? "nil")"]
                for p in mgr.allPermissions {
                    lines.append("\(p.rawValue)=\(mgr.status(for: p).rawValue)")
                }
                try? lines.joined(separator: "\n").write(toFile: outFile, atomically: true, encoding: .utf8)
                mgr.stopMonitoring()
            }
            return
        }
        await MainActor.run {
            let app = NSApplication.shared
            let delegate = AppDelegate()
            app.delegate = delegate
            app.setActivationPolicy(.regular)
            app.run()
        }
    }
}
