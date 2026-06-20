import AppKit
import SwiftUI
import PermissionPilot

/// Wires up the demo: a permission manager, a main status window, and the
/// onboarding wizard (shown automatically on first run, re-openable anytime).
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    private var manager: PermissionManager!
    private var mainWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        installMainMenu()

        manager = PermissionManager(
            required: [.accessibility, .screenRecording, .inputMonitoring],
            optional: [.fullDiskAccess]
        )

        showMainWindow()

        if !PermissionPilot.hasCompletedOnboarding {
            presentOnboarding()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    // MARK: Onboarding

    private func presentOnboarding() {
        var configuration = OnboardingConfiguration(appName: "PermissionPilot Demo")
        configuration.welcomeSubtitle =
            "PermissionPilot Demo needs a few macOS permissions to work — this takes about a minute."
        configuration.reasons = [
            .accessibility: "So the demo can resize windows with your hotkey.",
            .screenRecording: "So the demo can capture the window you're sharing.",
            .inputMonitoring: "So the demo can detect your global shortcuts.",
            .fullDiskAccess: "So the demo can back up the folders you pick.",
        ]

        PermissionPilot.presentOnboarding(manager: manager, configuration: configuration)
    }

    // MARK: Main window

    private func showMainWindow() {
        let content = DemoContentView(manager: manager) { [weak self] in
            self?.presentOnboarding()
        }
        let hosting = NSHostingController(rootView: content)
        let window = NSWindow(contentViewController: hosting)
        window.title = "PermissionPilot Demo"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.setContentSize(NSSize(width: 680, height: 540))
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        mainWindow = window
    }

    // MARK: Menu

    private func installMainMenu() {
        let mainMenu = NSMenu()
        let appItem = NSMenuItem()
        mainMenu.addItem(appItem)

        let appMenu = NSMenu()
        appMenu.addItem(
            withTitle: "Quit PermissionPilot Demo",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        appItem.submenu = appMenu
        NSApp.mainMenu = mainMenu
    }
}
