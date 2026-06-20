import SwiftUI
import PermissionPilotCore

/// A responsive grid of ``PermissionTile``s — the grid counterpart to
/// ``PermissionChecklist``. Renders the same set of permissions (implemented +
/// "coming soon") as adaptive, uniform-height tiles.
public struct PermissionGrid: View {
    @ObservedObject private var manager: PermissionManager
    private let permissions: [Permission]
    private let reasonOverrides: [Permission: String]
    private let minTileWidth: CGFloat

    /// - Parameters:
    ///   - manager: The permission engine to observe.
    ///   - permissions: Which permissions to show (default: the manager's full set).
    ///   - reasonOverrides: Per-permission reason copy overrides.
    ///   - minTileWidth: Minimum tile width for the adaptive layout (default 108).
    public init(
        manager: PermissionManager,
        permissions: [Permission]? = nil,
        reasonOverrides: [Permission: String] = [:],
        minTileWidth: CGFloat = 108
    ) {
        self.manager = manager
        self.permissions = permissions ?? manager.allPermissions
        self.reasonOverrides = reasonOverrides
        self.minTileWidth = minTileWidth
    }

    public var body: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: minTileWidth), spacing: PPDesign.s12)],
            spacing: PPDesign.s12
        ) {
            ForEach(permissions) { permission in
                PermissionTile(
                    manager: manager,
                    permission: permission,
                    reasonOverride: reasonOverrides[permission]
                )
            }
        }
    }
}
