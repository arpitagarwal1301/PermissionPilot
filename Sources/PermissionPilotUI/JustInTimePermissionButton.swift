import SwiftUI
import PermissionPilotCore

/// A just-in-time control for requesting a *single* permission at the point of
/// use — for optional capabilities (e.g. Camera/Microphone) you'd rather defer
/// than show in the upfront checklist.
///
/// Shows a green "Granted" confirmation once the permission is granted, otherwise
/// a button that prompts (or deep-links) and live-updates when the user returns.
public struct JustInTimePermissionButton: View {
    @ObservedObject private var manager: PermissionManager
    private let permission: Permission
    private let label: String?

    @Environment(\.permissionPilotTint) private var tint

    /// - Parameters:
    ///   - manager: The permission engine to observe.
    ///   - permission: The single permission to request.
    ///   - label: Optional button title (default "Enable \(permission title)").
    public init(
        manager: PermissionManager,
        permission: Permission,
        label: String? = nil
    ) {
        self.manager = manager
        self.permission = permission
        self.label = label
    }

    private var isGranted: Bool { manager.status(for: permission) == .granted }
    private var title: String { label ?? ppFormat("action.enable.named", manager.info(for: permission).title) }

    public var body: some View {
        if isGranted {
            Label(ppLocalized("state.granted"), systemImage: "checkmark.circle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(PPColor.granted)
                .accessibilityLabel(ppFormat("jit.a11y.granted", manager.info(for: permission).title))
        } else {
            Button(title) { manager.request(permission) }
                .buttonStyle(.borderedProminent)
                .applyingPermissionPilotTint(tint)
        }
    }
}
