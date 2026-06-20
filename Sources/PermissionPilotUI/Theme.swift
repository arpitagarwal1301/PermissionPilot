import SwiftUI

/// Host-supplied accent override. When `nil`, components use the system
/// `Color.accentColor` (which follows the user's accent). Green is never used
/// here — it is reserved for the granted state.
private struct PermissionPilotTintKey: EnvironmentKey {
    static let defaultValue: Color? = nil
}

extension EnvironmentValues {
    /// The resolved PermissionPilot tint, if a host set one.
    public var permissionPilotTint: Color? {
        get { self[PermissionPilotTintKey.self] }
        set { self[PermissionPilotTintKey.self] = newValue }
    }
}

extension View {
    /// Overrides the accent color used by PermissionPilot components (buttons,
    /// step dots, active states). Pass `nil` to follow the system accent.
    public func permissionPilotTint(_ color: Color?) -> some View {
        environment(\.permissionPilotTint, color)
    }

    /// Resolves the effective tint (host override → system accent) and applies
    /// it via `.tint`, so descendant controls pick it up.
    func applyingPermissionPilotTint(_ override: Color?) -> some View {
        tint(override ?? .accentColor)
    }
}
