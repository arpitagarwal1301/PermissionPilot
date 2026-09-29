import SwiftUI
import AppKit
import Combine
import PermissionPilotCore

/// One floating "how to grant this" panel for the manual-add permissions
/// (Accessibility, Screen Recording, Input Monitoring, Full Disk Access).
///
/// A popover can't do this job: it closes the moment System Settings comes
/// forward — exactly when the user needs the draggable icon — and every
/// **Enable** click spawned a fresh one. This panel instead:
/// - is a single, reused, non-activating floating window that stays above
///   System Settings and doesn't hide when the host app deactivates;
/// - docks beside the System Settings window once it appears (unless the user
///   has moved the panel);
/// - switches content in place when another permission's **Enable** is clicked;
/// - shows a confirmation and closes itself once the permission is granted.
///
/// ```swift
/// manager.request(.accessibility)          // adds the app to the list + opens it
/// ManualAddHelper.show(manager: manager, permission: .accessibility)
/// ```
@MainActor
public final class ManualAddHelper: NSObject, NSWindowDelegate {

    private static var current: ManualAddHelper?

    private let manager: PermissionManager
    private let model: Model
    private let panel: NSPanel
    private var statusObserver: AnyCancellable?
    private var closeWork: DispatchWorkItem?
    private var dockTimer: Timer?
    private var dockAttempts = 0
    private var userMovedPanel = false

    // MARK: Public API

    /// Shows the helper for `permission`, or switches the visible helper to it.
    ///
    /// Does not request or open anything itself — pair it with
    /// ``PermissionManager/request(_:)``, which adds the app to the list where
    /// macOS allows and opens the pane.
    ///
    /// - Parameters:
    ///   - appURL: The bundle to drag (defaults to the running app).
    ///   - appName: Display name for copy (defaults to the running app's).
    ///   - tint: Accent for buttons and the drag zone (`nil` = system accent).
    ///   - colorScheme: Pins light/dark; `nil` follows the system.
    public static func show(
        manager: PermissionManager,
        permission: Permission,
        appURL: URL = Bundle.main.bundleURL,
        appName: String = Bundle.main.permissionPilotAppName,
        tint: Color? = nil,
        colorScheme: ColorScheme? = nil
    ) {
        if let helper = current, helper.manager === manager, helper.model.appURL == appURL {
            helper.model.tint = tint
            helper.switchTo(permission, colorScheme: colorScheme)
            return
        }
        current?.close()
        let helper = ManualAddHelper(manager: manager, permission: permission, appURL: appURL,
                                     appName: appName, tint: tint)
        current = helper
        helper.switchTo(permission, colorScheme: colorScheme)
    }

    /// Closes the helper if it's showing. Hosts call this when their onboarding
    /// finishes; ``OnboardingPresenter`` does it automatically.
    public static func close() {
        current?.close()
    }

    /// Whether the helper panel is currently on screen.
    public static var isShowing: Bool { current != nil }

    // MARK: Lifecycle

    private init(manager: PermissionManager, permission: Permission, appURL: URL,
                 appName: String, tint: Color?) {
        self.manager = manager
        self.model = Model(permission: permission, appURL: appURL, appName: appName, tint: tint)

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 320),
            styleMask: [.titled, .closable, .utilityWindow, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false      // NSPanel defaults to true — that's the bug we're fixing
        panel.isReleasedWhenClosed = false   // ARC owns it
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.title = ppFormat("helper.windowTitle", appName)
        self.panel = panel
        super.init()

        let root = HelperView(manager: manager, model: model) { [weak self] in self?.returnToApp() }
        let hosting = NSHostingController(rootView: root)
        if #available(macOS 13.0, *) {
            hosting.sizingOptions = .preferredContentSize
        }
        panel.contentViewController = hosting
        panel.setContentSize(hosting.view.fittingSize)
        panel.delegate = self
        placeAtScreenEdge()

        statusObserver = manager.$statuses
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.statusChanged() }
    }

    private func switchTo(_ permission: Permission, colorScheme: ColorScheme?) {
        if let colorScheme {
            panel.appearance = NSAppearance(named: colorScheme == .dark ? .darkAqua : .aqua)
        } else {
            panel.appearance = nil
        }
        model.permission = permission
        closeWork?.cancel()
        closeWork = nil
        if #unavailable(macOS 13.0) {
            panel.setContentSize(panel.contentViewController?.view.fittingSize ?? panel.frame.size)
        }
        panel.orderFrontRegardless()
        startDocking()
        statusChanged()
    }

    private func close() {
        closeWork?.cancel()
        dockTimer?.invalidate()
        statusObserver = nil
        panel.delegate = nil
        panel.close()
        if Self.current === self { Self.current = nil }
    }

    private func returnToApp() {
        NSApp.activate(ignoringOtherApps: true)
        close()
    }

    /// Once the shown permission is granted, confirm briefly, then go away.
    private func statusChanged() {
        guard manager.status(for: model.permission) == .granted else {
            closeWork?.cancel()
            closeWork = nil
            return
        }
        guard closeWork == nil else { return }
        let work = DispatchWorkItem { [weak self] in self?.close() }
        closeWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: work)
    }

    // MARK: NSWindowDelegate

    /// Sent only for user-initiated moves (title bar / background drag) — from
    /// then on we stop docking so we never yank the panel from where they put it.
    public func windowWillMove(_ notification: Notification) {
        userMovedPanel = true
        dockTimer?.invalidate()
    }

    public func windowWillClose(_ notification: Notification) {
        closeWork?.cancel()
        dockTimer?.invalidate()
        statusObserver = nil
        if Self.current === self { Self.current = nil }
    }

    // MARK: Placement

    /// Until System Settings shows up: the right edge of the active screen.
    private func placeAtScreenEdge() {
        guard let visible = (NSScreen.main ?? NSScreen.screens.first)?.visibleFrame else { return }
        let size = panel.frame.size
        panel.setFrameOrigin(NSPoint(x: visible.maxX - size.width - 24,
                                     y: visible.midY - size.height / 2))
    }

    /// System Settings opens asynchronously (and may already be open), so poll
    /// briefly for its window and dock beside it once found.
    private func startDocking() {
        dockTimer?.invalidate()
        guard !userMovedPanel else { return }
        dockAttempts = 0
        dockTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.dockTick() }
        }
    }

    private func dockTick() {
        dockAttempts += 1
        guard !userMovedPanel, dockAttempts <= 20 else { dockTimer?.invalidate(); return }
        guard let settings = Self.systemSettingsFrame() else { return }
        let screen = NSScreen.screens.first { $0.frame.intersects(settings) } ?? NSScreen.main
        guard let visible = screen?.visibleFrame else { return }
        panel.setFrameOrigin(Self.dockedOrigin(panel: panel.frame.size, beside: settings, within: visible))
        dockTimer?.invalidate()
    }

    /// Where to put the panel next to System Settings (AppKit coordinates):
    /// to its right if that fits on screen, else to its left, else overlapping
    /// its right edge — top-aligned with it and clamped inside `visible`.
    nonisolated static func dockedOrigin(panel: CGSize, beside settings: CGRect,
                                         within visible: CGRect, gap: CGFloat = 12) -> CGPoint {
        var x: CGFloat
        if settings.maxX + gap + panel.width <= visible.maxX {
            x = settings.maxX + gap
        } else if settings.minX - gap - panel.width >= visible.minX {
            x = settings.minX - gap - panel.width
        } else {
            x = visible.maxX - panel.width - gap
        }
        x = min(max(x, visible.minX), visible.maxX - panel.width)
        var y = settings.maxY - panel.height
        y = min(max(y, visible.minY), visible.maxY - panel.height)
        return CGPoint(x: x, y: y)
    }

    /// The frontmost on-screen System Settings window, in AppKit coordinates.
    /// Window bounds and owners need no permission (only titles are gated).
    private static func systemSettingsFrame() -> CGRect? {
        let pids = Set(NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.systempreferences")
            .map(\.processIdentifier))
        guard !pids.isEmpty,
              let primary = NSScreen.screens.first,
              let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements],
                                                    kCGNullWindowID) as? [[String: Any]]
        else { return nil }
        // The list is front-to-back, so the first match is the frontmost.
        for window in info {
            guard let pid = window[kCGWindowOwnerPID as String] as? pid_t, pids.contains(pid),
                  (window[kCGWindowLayer as String] as? Int) == 0,
                  let bounds = window[kCGWindowBounds as String] as? NSDictionary,
                  let rect = CGRect(dictionaryRepresentation: bounds),
                  rect.width > 200, rect.height > 200
            else { continue }
            // Quartz window bounds are top-left–origin; flip to AppKit's.
            return CGRect(x: rect.minX, y: primary.frame.maxY - rect.maxY,
                          width: rect.width, height: rect.height)
        }
        return nil
    }
}

// MARK: - Content

extension ManualAddHelper {

    @MainActor
    final class Model: ObservableObject {
        @Published var permission: Permission
        @Published var tint: Color?
        let appURL: URL
        let appName: String

        init(permission: Permission, appURL: URL, appName: String, tint: Color?) {
            self.permission = permission
            self.appURL = appURL
            self.appName = appName
            self.tint = tint
        }
    }

    struct HelperView: View {
        @ObservedObject var manager: PermissionManager
        @ObservedObject var model: Model
        let onReturn: () -> Void

        private var isGranted: Bool { manager.status(for: model.permission) == .granted }

        var body: some View {
            Group {
                if isGranted {
                    grantedView
                } else {
                    DragToAuthorizeView(manager: manager, permission: model.permission,
                                        appURL: model.appURL, appName: model.appName)
                        .id(model.permission) // fresh pulse/state per permission
                }
            }
            .padding(.top, PPDesign.s8) // clear the transparent title bar's close button
            .permissionPilotTint(model.tint)
        }

        private var grantedView: some View {
            VStack(spacing: PPDesign.s12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(PPColor.granted)
                Text(ppFormat("helper.granted", model.appName, manager.info(for: model.permission).title))
                    .font(.headline)
                    .multilineTextAlignment(.center)
                Button(ppFormat("helper.returnToApp", model.appName), action: onReturn)
                    .buttonStyle(.borderedProminent)
                    .applyingPermissionPilotTint(model.tint)
            }
            .padding(PPDesign.s24)
            .frame(width: 420)
        }
    }
}
