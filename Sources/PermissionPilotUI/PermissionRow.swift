import SwiftUI
import PermissionPilotCore

/// A single permission row: icon tile + SF Symbol, bold name + one-line reason,
/// and a trailing state — green ✓ "Granted" or a blue "Enable" action.
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("\(info.title). \(reason)"))
        .accessibilityValue(Text(accessibilityStateText))
        .accessibilityHint(isGranted ? Text("") : Text("Activates to enable in System Settings"))
    }

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
        if isGranted {
            HStack(spacing: PPDesign.s4 + 2) {
                Image(systemName: "checkmark.circle.fill")
                Text("Granted")
                    .fontWeight(.semibold)
            }
            .font(.subheadline)
            .foregroundStyle(PPColor.granted)
        } else {
            Button("Enable") { manager.request(permission) }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .applyingPermissionPilotTint(tint)
        }
    }

    private var accessibilityStateText: String {
        switch status {
        case .granted:       return "Granted"
        case .denied:        return "Not enabled"
        case .notDetermined: return "Not enabled"
        case .unknown:       return "Status unavailable"
        }
    }
}
