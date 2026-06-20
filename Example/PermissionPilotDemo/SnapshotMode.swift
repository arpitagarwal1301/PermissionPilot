import AppKit
import SwiftUI
import PermissionPilot

/// Renders the wizard screens to PNGs by hosting them in a real `NSWindow` and
/// capturing its backing store with `cacheDisplay` (retina-aware, and unlike
/// `ImageRenderer` it renders `ScrollView` content correctly). Capturing your
/// own window needs no Screen Recording permission. Run with:
/// `swift run PermissionPilotDemo --snapshot [outDir]`.
///
/// Doubles as the generator for README / marketing assets.
@MainActor
enum SnapshotMode {
    static func run(outDir: String) {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory) // no Dock icon / bounce
        try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

        // Fixed, representative state → "2 of 4 enabled" (matches the design mock).
        let manager = PermissionManager(
            required: [.accessibility, .screenRecording, .inputMonitoring],
            optional: [.fullDiskAccess],
            statuses: [
                .accessibility: .granted,
                .screenRecording: .granted,
                .inputMonitoring: .denied,
                .fullDiskAccess: .denied,
            ]
        )
        var cfg = OnboardingConfiguration(appName: "YourApp")
        cfg.reasons = [
            .accessibility: "So YourApp can resize windows with your hotkey.",
            .screenRecording: "So YourApp can capture the window you're sharing.",
            .fullDiskAccess: "So YourApp can back up the folders you pick.",
            .inputMonitoring: "So YourApp can detect your global shortcuts.",
        ]

        let steps: [(String, OnboardingView.Step)] = [
            ("1-welcome", .welcome),
            ("2-permissions", .permissions),
            ("3-done", .done),
        ]
        let schemes: [(String, ColorScheme, NSAppearance.Name)] = [
            ("light", .light, .aqua),
            ("dark", .dark, .darkAqua),
        ]

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 540),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.center()

        for (schemeName, scheme, appearanceName) in schemes {
            NSApp.appearance = NSAppearance(named: appearanceName)
            window.appearance = NSAppearance(named: appearanceName)
            for (stepName, step) in steps {
                let root = OnboardingView(manager: manager, configuration: cfg, initialStep: step)
                    .frame(width: 700, height: 540)
                    .environment(\.colorScheme, scheme)
                window.contentViewController = NSHostingController(rootView: root)
                window.orderFrontRegardless()
                window.displayIfNeeded()
                // Let SwiftUI commit its layout/render before capturing.
                RunLoop.current.run(until: Date().addingTimeInterval(0.4))
                capture(window, to: "\(outDir)/\(stepName)_\(schemeName).png")
            }
        }
        window.orderOut(nil)
        print("WROTE snapshots to \(outDir)")
    }

    static func capture(_ window: NSWindow, to path: String) {
        guard let view = window.contentView,
              let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
            print("FAILED (no rep): \(path)")
            return
        }
        view.cacheDisplay(in: view.bounds, to: rep)
        guard let png = rep.representation(using: .png, properties: [:]) else {
            print("FAILED (no png): \(path)")
            return
        }
        try? png.write(to: URL(fileURLWithPath: path))
        print("OK: \(path) (\(rep.pixelsWide)x\(rep.pixelsHigh))")
    }
}
