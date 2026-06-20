import SwiftUI
import PermissionPilotCore

/// A single permission **grid** cell: a centered icon + name with a small
/// top-right status badge — green ✓ (granted), blue ⊕ (tap to enable), or a gray
/// clock (coming soon, disabled). Uniform height so the grid stays even and the
/// List↔Grid switch is visually consistent.
public struct PermissionTile: View {
    @ObservedObject private var manager: PermissionManager
    private let permission: Permission
    private let reasonOverride: String?

    @Environment(\.colorScheme) private var scheme
    @Environment(\.permissionPilotTint) private var tint
    @Environment(\.openURL) private var openURL
    @State private var showsDragHelp = false

    public init(
        manager: PermissionManager,
        permission: Permission,
        reasonOverride: String? = nil
    ) {
        self.manager = manager
        self.permission = permission
        self.reasonOverride = reasonOverride
    }

    private var info: PermissionInfo { manager.info(for: permission) }
    private var reason: String { reasonOverride ?? info.reason }
    private var status: PermissionStatus { manager.status(for: permission) }
    private var isGranted: Bool { status == .granted }
    private var isComingSoon: Bool { !permission.isImplemented }
    private var actionable: Bool { !isComingSoon && !isGranted }

    public var body: some View {
        VStack(spacing: PPDesign.s8 + 2) {
            Image(systemName: info.systemImage)
                .font(.system(size: 24, weight: .regular))
                .foregroundStyle(.primary)
            Text(info.title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 104)
        .padding(.horizontal, PPDesign.s8)
        .background(
            RoundedRectangle(cornerRadius: PPDesign.cardRadius, style: .continuous)
                .fill(Color.primary.opacity(scheme == .dark ? 0.06 : 0.035))
        )
        .overlay(
            RoundedRectangle(cornerRadius: PPDesign.cardRadius, style: .continuous)
                .strokeBorder(PPColor.separator, lineWidth: 0.5)
        )
        .overlay(alignment: .topTrailing) { badge.padding(PPDesign.s8) }
        .opacity(isComingSoon ? 0.55 : 1)
        .help(isComingSoon ? "\(reason) (coming soon)" : reason)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(info.title))
        .accessibilityValue(Text(stateText))
        .accessibilityAddTraits(actionable ? .isButton : [])
        .accessibilityAction { if actionable { enable() } }
    }

    // MARK: Badge

    @ViewBuilder
    private var badge: some View {
        if isComingSoon {
            if let url = permission.documentationURL {
                Button { openURL(url) } label: {
                    badgeCircle(fill: Color.primary.opacity(0.12), symbol: "info", foreground: .secondary)
                }
                .buttonStyle(.plain)
                .help("Apple documentation for \(info.title)")
                .accessibilityLabel("Learn more about \(info.title) (Apple documentation)")
            } else {
                badgeCircle(fill: Color.primary.opacity(0.12), symbol: "clock", foreground: .secondary)
            }
        } else if isGranted {
            badgeCircle(fill: PPColor.granted, symbol: "checkmark", foreground: Color(nsColor: .windowBackgroundColor))
        } else {
            Button(action: enable) {
                badgeCircle(fill: tint ?? .accentColor, symbol: "plus",
                            foreground: Color(nsColor: .windowBackgroundColor))
            }
            .buttonStyle(.plain)
            .help("Enable \(info.title)")
            .popover(isPresented: $showsDragHelp, arrowEdge: .bottom) {
                DragToAuthorizeView(manager: manager, permission: permission)
            }
        }
    }

    private func badgeCircle<F: ShapeStyle>(fill: F, symbol: String, foreground: Color) -> some View {
        Circle()
            .fill(fill)
            .frame(width: 20, height: 20)
            .overlay(
                Image(systemName: symbol)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(foreground)
            )
    }

    private func enable() {
        if permission.supportsManualAdd {
            showsDragHelp = true
        } else {
            manager.request(permission)
        }
    }

    private var stateText: String {
        if isComingSoon { return "Coming soon" }
        if isGranted { return "Granted" }
        return "Not enabled"
    }
}
