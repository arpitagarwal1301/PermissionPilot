import SwiftUI
import AppKit
import PermissionPilotCore

/// Presents ``OnboardingView`` in a real, titled `NSWindow` — so the OS provides
/// genuine window chrome (traffic lights), not a drawn imitation.
///
/// The presenter retains itself while visible, so callers don't have to hold a
/// reference. It releases on Finish or when the window closes.
@MainActor
public final class OnboardingPresenter: NSObject, NSWindowDelegate {

    private static var active: OnboardingPresenter?
    private var window: NSWindow?
    private var onFinish: (() -> Void)?

    /// Presents the wizard in a centered window and brings the app forward.
    @discardableResult
    public static func present(
        manager: PermissionManager,
        configuration: OnboardingConfiguration,
        onFinish: (() -> Void)? = nil
    ) -> OnboardingPresenter {
        active?.close()
        let presenter = OnboardingPresenter()
        presenter.onFinish = onFinish
        presenter.show(manager: manager, configuration: configuration)
        active = presenter
        return presenter
    }

    private func show(manager: PermissionManager, configuration: OnboardingConfiguration) {
        let root = OnboardingView(manager: manager, configuration: configuration) { [weak self] in
            self?.handleFinish()
        }
        let hosting = NSHostingController(rootView: root)
        let window = NSWindow(contentViewController: hosting)
        // ARC owns `window` via the strong property; disable AppKit's
        // close-time release to avoid a double-free when the wizard closes.
        window.isReleasedWhenClosed = false
        window.title = configuration.appName
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.styleMask = [.titled, .closable, .miniaturizable, .fullSizeContentView]
        window.isMovableByWindowBackground = true
        window.setContentSize(NSSize(width: PPDesign.windowWidth, height: PPDesign.windowHeight))
        window.delegate = self
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.window = window
    }

    private func handleFinish() {
        let callback = onFinish
        close()
        callback?()
    }

    /// Closes the wizard window and releases the presenter.
    public func close() {
        window?.delegate = nil
        window?.close()
        window = nil
        if OnboardingPresenter.active === self {
            OnboardingPresenter.active = nil
        }
    }

    // MARK: NSWindowDelegate

    public func windowWillClose(_ notification: Notification) {
        window = nil
        if OnboardingPresenter.active === self {
            OnboardingPresenter.active = nil
        }
    }
}
