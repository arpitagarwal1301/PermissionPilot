import Foundation

/// The authorization status of a ``Permission``.
public enum PermissionStatus: String, Hashable, Sendable, CaseIterable {
    /// The permission is granted and usable.
    case granted
    /// The permission was explicitly denied (or restricted by policy).
    case denied
    /// The permission has not been requested yet (no decision recorded).
    case notDetermined
    /// The status could not be determined (e.g. unexpected API result).
    case unknown

    /// Convenience: `true` only when ``granted``.
    public var isGranted: Bool { self == .granted }

    /// Whether the user can still act to grant this (anything but ``granted``).
    public var isActionable: Bool { self != .granted }
}

/// Pure decision helpers over a status map — kept free of side effects so they
/// can be unit-tested without the live TCC database.
public enum PermissionDecision {
    /// Whether every permission in `permissions` is ``PermissionStatus/granted``
    /// in `statuses`. An empty list is vacuously granted.
    public static func allGranted(
        _ permissions: [Permission],
        in statuses: [Permission: PermissionStatus]
    ) -> Bool {
        permissions.allSatisfy { statuses[$0] == .granted }
    }

    /// The number of `permissions` that are ``PermissionStatus/granted`` in `statuses`.
    public static func grantedCount(
        _ permissions: [Permission],
        in statuses: [Permission: PermissionStatus]
    ) -> Int {
        permissions.reduce(into: 0) { count, permission in
            if statuses[permission] == .granted { count += 1 }
        }
    }
}
