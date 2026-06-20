import SwiftUI
import PermissionPilotCore

/// A multi-permission checklist card: a centered title, an "N of M enabled"
/// counter, and one ``PermissionRow`` per permission separated by hairlines.
///
/// Rows flip to ✓ automatically as the manager re-checks (the user returning
/// from System Settings), and the counter updates live.
public struct PermissionChecklist: View {
    @ObservedObject private var manager: PermissionManager
    private let permissions: [Permission]
    private let reasonOverrides: [Permission: String]
    private let title: String
    private let showsCard: Bool
    private let showsHeader: Bool

    @Environment(\.colorScheme) private var scheme

    /// - Parameters:
    ///   - manager: The permission engine to observe.
    ///   - permissions: Which permissions to show (default: the manager's full set).
    ///   - title: Card title (default "Permissions needed").
    ///   - reasonOverrides: Per-permission reason copy overrides.
    ///   - showsCard: Whether to draw the rounded card surface (default `true`).
    ///   - showsHeader: Whether to draw the title + counter header (default `true`).
    ///     Set `false` when embedding under a shared header (e.g. ``PermissionsView``).
    public init(
        manager: PermissionManager,
        permissions: [Permission]? = nil,
        title: String = "Permissions needed",
        reasonOverrides: [Permission: String] = [:],
        showsCard: Bool = true,
        showsHeader: Bool = true
    ) {
        self.manager = manager
        self.permissions = permissions ?? manager.allPermissions
        self.title = title
        self.reasonOverrides = reasonOverrides
        self.showsCard = showsCard
        self.showsHeader = showsHeader
    }

    private var grantedCount: Int { manager.grantedCount(of: permissions) }
    private var implementedCount: Int { permissions.filter(\.isImplemented).count }

    public var body: some View {
        VStack(spacing: 0) {
            if showsHeader { header }
            rows.padding(.top, showsHeader ? 0 : PPDesign.s4)
        }
        .padding(.horizontal, PPDesign.cardPadding)
        .padding(.bottom, PPDesign.s8)
        .frame(maxWidth: PPDesign.cardWidth)
        .modifier(CardSurface(enabled: showsCard))
    }

    private var header: some View {
        VStack(spacing: PPDesign.s4) {
            Text(title)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
            Text("\(grantedCount) of \(implementedCount) enabled")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, PPDesign.s24)
        .padding(.bottom, PPDesign.s16)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    private var rows: some View {
        VStack(spacing: 0) {
            ForEach(Array(permissions.enumerated()), id: \.element) { index, permission in
                PermissionRow(
                    manager: manager,
                    permission: permission,
                    reasonOverride: reasonOverrides[permission]
                )
                if index < permissions.count - 1 {
                    Divider().overlay(PPColor.separator)
                }
            }
        }
    }
}

/// Applies the rounded card surface (fill + hairline + soft shadow) when enabled.
private struct CardSurface: ViewModifier {
    let enabled: Bool

    func body(content: Content) -> some View {
        if enabled {
            content
                .background(
                    RoundedRectangle(cornerRadius: PPDesign.cardRadius, style: .continuous)
                        .fill(PPColor.card)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: PPDesign.cardRadius, style: .continuous)
                        .strokeBorder(PPColor.separator, lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
        } else {
            content
        }
    }
}
