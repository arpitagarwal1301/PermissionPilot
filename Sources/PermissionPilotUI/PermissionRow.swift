import SwiftUI
import PermissionPilotCore

/// A single permission row: icon tile + SF Symbol, bold name + one-line reason,
/// and a trailing state — green ✓ "Granted", a blue "Enable" action, or a dimmed
/// "Coming soon" for not-yet-implemented permissions.
///
/// Status is never conveyed by color alone: the granted state always pairs the
/// green check with the word "Granted", and the row's accessibility label spells
/// the state out for VoiceOver.
public struct PermissionRow: View {
    @ObservedObject private var manager: PermissionManager
    private let permission: Permission
    private let reasonOverride: String?

    @Environment(\.colorScheme) private var scheme
    @Environment(\.permissionPilotTint) private var tint
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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

    public var body: some View {
        HStack(spacing: PPDesign.rowIconTextGap) {
            iconTile
            VStack(alignment: .leading, spacing: PPDesign.s4 / 2) {
                Text(info.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(reason)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: PPDesign.s12)
            trailing
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: isGranted)
        }
        .frame(minHeight: PPDesign.rowHeight)
        .opacity(isComingSoon ? 0.55 : 1)
        .help(isComingSoon ? "\(reason) (coming soon)" : reason)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("\(info.title). \(reason)"))
        .accessibilityValue(Text(accessibilityStateText))
        .accessibilityHint(actionable ? Text("Activates to enable in System Settings") : Text(""))
        // Combining children flattens the trailing Button away, so restore the
        // button trait + activation on the row itself for VoiceOver / keyboard.
        .accessibilityAddTraits(actionable ? .isButton : [])
        .accessibilityAction { if actionable { manager.request(permission) } }
    }

    /// Whether the row offers a real "Enable" action (implemented + not granted).
    private var actionable: Bool { !isComingSoon && !isGranted }

    // MARK: Pieces

    private var iconTile: some View {
        RoundedRectangle(cornerRadius: PPDesign.iconTileRadius, style: .continuous)
            .fill(PPColor.iconTile(scheme))
            .frame(width: PPDesign.iconTileSize, height: PPDesign.iconTileSize)
            .overlay(
                Image(systemName: info.systemImage)
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(.primary)
            )
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var trailing: some View {
        if isComingSoon {
            HStack(spacing: PPDesign.s8) {
                Text("Coming soon")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, PPDesign.s8)
                    .padding(.vertical, 3)
                    .background(Capsule().strokeBorder(PPColor.separator))
                if let url = permission.documentationURL {
                    Button { openURL(url) } label: {
                        Image(systemName: "info.circle")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .help("Apple documentation for \(info.title)")
                    .accessibilityLabel("Learn more about \(info.title) (Apple documentation)")
                }
            }
        } else if isGranted {
            HStack(spacing: PPDesign.s4 + 2) {
                Image(systemName: "checkmark.circle.fill")
                Text("Granted").fontWeight(.semibold)
            }
            .font(.subheadline)
            .foregroundStyle(PPColor.granted)
        } else {
            // Permissions with no request API (Full Disk Access) can't be
            // prompted — guide the user to add the app via drag-to-authorize.
            // Manual-add panes (Accessibility / Screen Recording / Input
            // Monitoring / Full Disk Access) show the drag-to-authorize helper —
            // the app may not be listed yet. Camera/Mic use the system prompt.
            Button("Enable") {
                if permission.supportsManualAdd {
                    showsDragHelp = true
                } else {
                    manager.request(permission)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            .applyingPermissionPilotTint(tint)
            .popover(isPresented: $showsDragHelp, arrowEdge: .bottom) {
                DragToAuthorizeView(manager: manager, permission: permission)
            }
        }
    }

    private var accessibilityStateText: String {
        if isComingSoon { return "Coming soon" }
        switch status {
        case .granted:                  return "Granted"
        case .denied, .notDetermined:   return "Not enabled"
        case .unknown:                  return "Status unavailable"
        }
    }
}
