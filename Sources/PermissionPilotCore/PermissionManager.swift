import Foundation
import AppKit
import Combine

/// The live permission engine: an `@MainActor` `ObservableObject` that publishes
/// the current status of every declared permission and drives detection,
/// requests, deep-links, and relaunch.
///
/// Declare what your app needs, then observe `statuses` / `allRequiredGranted`
/// from SwiftUI:
///
/// ```swift
/// @StateObject var permissions = PermissionManager(
///     required: [.accessibility, .screenRecording],
///     optional: [.camera]
/// )
/// ```
///
/// The manager re-checks automatically when the app becomes active (the user
/// returning from System Settings) and via a light fallback poll, so rows flip
/// to ✓ without any manual refresh.
@MainActor
public final class PermissionManager: ObservableObject {

    /// Permissions the app cannot function without. Onboarding cannot be
    /// completed until all of these are granted.
    public let required: [Permission]

    /// Permissions that enhance the app but are skippable.
    public let optional: [Permission]

    /// Required + optional, in declaration order, de-duplicated.
    public let allPermissions: [Permission]

    /// Live status for every declared permission. Published for SwiftUI.
    @Published public private(set) var statuses: [Permission: PermissionStatus] = [:]

    private let infoOverrides: [Permission: PermissionInfo]
    private let pollInterval: TimeInterval
    private var activationObserver: NSObjectProtocol?
    private var pollTimer: Timer?

    /// Creates a manager for the given permissions.
    ///
    /// - Parameters:
    ///   - required: Permissions that must be granted to finish onboarding.
    ///   - optional: Skippable permissions, shown after the required ones.
    ///   - infoOverrides: Per-permission title/reason/icon overrides.
    ///   - pollInterval: Fallback re-check interval in seconds (default 2).
    public init(
        required: [Permission],
        optional: [Permission] = [],
        infoOverrides: [Permission: PermissionInfo] = [:],
        pollInterval: TimeInterval = 2.0
    ) {
        self.required = required
        let dedupedOptional = optional.filter { !required.contains($0) }
        self.optional = dedupedOptional
        self.allPermissions = required + dedupedOptional
        self.infoOverrides = infoOverrides
        self.pollInterval = pollInterval
        refresh()
        startMonitoring()
    }

    deinit {
        if let observer = activationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        pollTimer?.invalidate()
    }

    // MARK: Querying

    /// The current status for `permission` (``PermissionStatus/unknown`` if not tracked).
    public func status(for permission: Permission) -> PermissionStatus {
        statuses[permission] ?? .unknown
    }

    /// The (possibly overridden) display info for `permission`.
    public func info(for permission: Permission) -> PermissionInfo {
        infoOverrides[permission] ?? permission.defaultInfo
    }

    /// Whether every `required` permission is granted.
    public var allRequiredGranted: Bool {
        PermissionDecision.allGranted(required, in: statuses)
    }

    /// Whether every `optional` permission is granted.
    public var allOptionalGranted: Bool {
        PermissionDecision.allGranted(optional, in: statuses)
    }

    /// Count of granted permissions among `permissions` (default: all).
    public func grantedCount(of permissions: [Permission]? = nil) -> Int {
        PermissionDecision.grantedCount(permissions ?? allPermissions, in: statuses)
    }

    /// Whether any granted permission may need a relaunch to take effect.
    public var needsRelaunch: Bool {
        allPermissions.contains { $0.mayRequireRelaunch && status(for: $0) == .granted }
    }

    // MARK: Actions

    /// Re-detects the status of every declared permission. Cheap; safe to call often.
    public func refresh() {
        var updated = statuses
        for permission in allPermissions {
            updated[permission] = PermissionProbe.status(for: permission)
        }
        if updated != statuses {
            statuses = updated
        }
    }

    /// Requests `permission` — shows a system prompt where the OS allows, else
    /// opens the System Settings deep-link — then refreshes status.
    public func request(_ permission: Permission) {
        PermissionProbe.request(permission) { [weak self] status in
            Task { @MainActor in
                guard let self else { return }
                self.statuses[permission] = status
                self.refresh()
            }
        }
    }

    /// Opens the System Settings pane for `permission` without prompting.
    @discardableResult
    public func openSettings(for permission: Permission) -> Bool {
        SystemSettingsLink.open(permission)
    }

    /// Relaunches the app so freshly-granted permissions (Input Monitoring,
    /// pre-Sequoia Screen Recording) take effect, then terminates this instance.
    public func quitAndReopen() {
        Relauncher.relaunch()
    }

    // MARK: Monitoring

    /// Begins auto re-checking on `didBecomeActive` plus a light fallback poll.
    /// Called automatically by `init`.
    public func startMonitoring() {
        guard activationObserver == nil else { return }
        activationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        let timer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        timer.tolerance = pollInterval * 0.25
        pollTimer = timer
    }

    /// Stops auto re-checking. (Monitoring also stops on deinit.)
    public func stopMonitoring() {
        if let observer = activationObserver {
            NotificationCenter.default.removeObserver(observer)
            activationObserver = nil
        }
        pollTimer?.invalidate()
        pollTimer = nil
    }
}
