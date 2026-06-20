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

        for (schemeName, scheme, appearanceName) in schemes {
            NSApp.appearance = NSAppearance(named: appearanceName)
            for (stepName, step) in steps {
                let root = OnboardingView(manager: manager, configuration: cfg, initialStep: step)
                    .environment(\.colorScheme, scheme)
                render(root, size: NSSize(width: 700, height: 540),
                       appearance: appearanceName, to: "\(outDir)/\(stepName)_\(schemeName).png")
            }
            // Drag-to-authorize helper (Full Disk Access). Use the built .app's
            // icon if present (the unbundled snapshot binary would show a folder).
            let appCandidate = Bundle.main.bundleURL.deletingLastPathComponent()
                .appendingPathComponent("PermissionPilot Demo.app")
            let iconURL = FileManager.default.fileExists(atPath: appCandidate.path) ? appCandidate : Bundle.main.bundleURL
            let drag = DragToAuthorizeView(manager: manager, permission: .fullDiskAccess, appURL: iconURL, appName: "YourApp")
                .environment(\.colorScheme, scheme)
            render(drag, size: NSSize(width: 420, height: 440),
                   appearance: appearanceName, to: "\(outDir)/4-drag-to-authorize_\(schemeName).png")
        }
        // Hero flow banner composed from the real app screens (dark only).
        NSApp.appearance = NSAppearance(named: .darkAqua)
        let bm = PermissionManager(
            required: [.accessibility, .screenRecording, .inputMonitoring],
            optional: [.fullDiskAccess, .camera, .microphone],
            statuses: [
                .accessibility: .granted, .screenRecording: .granted, .inputMonitoring: .denied,
                .fullDiskAccess: .denied, .camera: .granted, .microphone: .denied,
            ]
        )
        var bcfg = OnboardingConfiguration(appName: "YourApp")
        bcfg.reasons = [
            .accessibility: "Resize windows with your hotkey.",
            .screenRecording: "Capture the window you're sharing.",
            .inputMonitoring: "Detect your global shortcuts.",
            .fullDiskAccess: "Back up the folders you pick.",
            .camera: "Use the camera for video.",
            .microphone: "Use the mic for audio.",
        ]
        let banner = HeroFlowBanner(manager: bm, configuration: bcfg).environment(\.colorScheme, .dark)
        render(banner, size: NSSize(width: 1160, height: 600), appearance: .darkAqua,
               to: "\(outDir)/flow-hero_dark.png")

        // Permission board (real PermissionsView) — list + grid, full roadmap.
        NSApp.appearance = NSAppearance(named: .darkAqua)
        let boardMgr = PermissionManager(
            required: [.accessibility, .screenRecording, .inputMonitoring],
            optional: [.fullDiskAccess, .camera, .microphone],
            statuses: [
                .accessibility: .granted, .screenRecording: .granted, .inputMonitoring: .denied,
                .fullDiskAccess: .denied, .camera: .granted, .microphone: .denied,
            ]
        )
        let boardGrid = PermissionsView(manager: boardMgr, permissions: Permission.allCases, defaultLayout: .grid)
            .environment(\.colorScheme, .dark)
        render(boardGrid, size: NSSize(width: 600, height: 680), appearance: .darkAqua,
               to: "\(outDir)/board-grid_dark.png")
        let boardList = PermissionsView(manager: boardMgr, permissions: Permission.allCases, defaultLayout: .list)
            .environment(\.colorScheme, .dark)
        render(boardList, size: NSSize(width: 600, height: 1180), appearance: .darkAqua,
               to: "\(outDir)/board-list_dark.png")

        print("WROTE snapshots to \(outDir)")
    }

    static func render<V: View>(_ view: V, size: NSSize, appearance: NSAppearance.Name, to path: String) {
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless], backing: .buffered, defer: false
        )
        window.isReleasedWhenClosed = false
        window.appearance = NSAppearance(named: appearance)
        window.contentViewController = NSHostingController(
            rootView: view
                .frame(width: size.width, height: size.height)
                .background(Color(nsColor: .windowBackgroundColor))
        )
        window.center()
        window.orderFrontRegardless()
        window.displayIfNeeded()
        // Let SwiftUI commit its layout/render before capturing.
        RunLoop.current.run(until: Date().addingTimeInterval(0.4))
        capture(window, to: path)
        window.orderOut(nil)
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
