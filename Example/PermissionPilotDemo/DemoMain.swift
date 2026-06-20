// PermissionPilotDemo — entry point.
//
// A bare AppKit entry (rather than a SwiftUI `@main App`) so the demo runs
// reliably as an unbundled SPM executable via `swift run PermissionPilotDemo`,
// with a real Dock presence and menu. The async `main()` hops onto the main
// actor before constructing the (@MainActor) app delegate.

import AppKit

@main
struct DemoMain {
    static func main() async {
        await MainActor.run {
            let app = NSApplication.shared
            let delegate = AppDelegate()
            app.delegate = delegate
            app.setActivationPolicy(.regular)
            app.run()
        }
    }
}
