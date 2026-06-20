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

        // Required stays minimal (the three system-prompt panes a window-automation
        // app actually needs). A tasteful optional subset showcases live consent
        // prompts; the main window's full board (Permission.allCases) surfaces the
        // rest, including the deep-link-only Automation / Local Network.
        manager = PermissionManager(
            required: [.accessibility, .screenRecording, .inputMonitoring],
            optional: [.fullDiskAccess, .camera, .microphone,
                       .contacts, .photos, .calendars, .location]
        )

        showMainWindow()

        if !PermissionPilot.hasCompletedOnboarding {
            presentOnboarding()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    // Reopening (Dock click / `open` while running) re-shows the existing main
    // window instead of spawning another one.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { mainWindow?.makeKeyAndOrderFront(nil) }
        return true
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
            .contacts: "So the demo can show people in your shared sessions.",
            .photos: "So the demo can attach screenshots from your library.",
            .calendars: "So the demo can schedule recordings on your calendar.",
            .location: "So the demo can tag captures with where you are.",
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
        window.isReleasedWhenClosed = false
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
