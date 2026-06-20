import SwiftUI
import AppKit
import PermissionPilotCore

/// A guided "how to grant this" helper, shown from a permission's **Enable**.
///
/// It adapts to the permission:
/// - **Manual-add panes** (Accessibility, Screen Recording, Input Monitoring,
///   Full Disk Access): drag the app icon into the list, or use **+** — the app
///   may not be listed yet.
/// - **Prompt-based** (Camera, Microphone): request access via the system prompt;
///   the app only appears in that list after it responds.
///
/// Built entirely on AppKit/SwiftUI APIs — no third-party code.
public struct DragToAuthorizeView: View {
    @ObservedObject private var manager: PermissionManager
    private let permission: Permission
    private let appURL: URL
    private let appName: String

    @Environment(\.permissionPilotTint) private var tint
    @Environment(\.colorScheme) private var scheme

    /// - Parameters:
    ///   - manager: The permission engine (used for the Settings deep-link + title).
    ///   - permission: The permission to authorize (e.g. `.fullDiskAccess`).
    ///   - appURL: The app bundle to drag/reveal (defaults to the running app).
    ///   - appName: Display name used in copy (defaults to the running app's).
    public init(
        manager: PermissionManager,
        permission: Permission,
        appURL: URL = Bundle.main.bundleURL,
        appName: String = Bundle.main.permissionPilotAppName
    ) {
        self.manager = manager
        self.permission = permission
        self.appURL = appURL
        self.appName = appName
    }

    private var permissionTitle: String { manager.info(for: permission).title }

    public var body: some View {
        VStack(alignment: .leading, spacing: PPDesign.s16) {
            VStack(alignment: .leading, spacing: PPDesign.s4) {
                Text("Give \(appName) \(permissionTitle)")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if permission.supportsManualAdd {
                manualAddSteps
            } else {
                promptSteps
            }

            Divider()

            Label(footerNote, systemImage: "info.circle")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(PPDesign.s20)
        .frame(width: 420)
    }

    private var subtitle: String {
        permission.supportsManualAdd
            ? "macOS can’t ask for this one — you add \(appName) to the list yourself."
            : "macOS shows a one-time prompt. \(appName) appears in the \(permissionTitle) list only after it responds."
    }

    private var footerNote: String {
        permission.supportsManualAdd
            ? "Already in the list? Just switch it on."
            : "Denied it earlier? Re-enable \(appName) in System Settings → Privacy & Security → \(permissionTitle)."
    }

    // MARK: Step groups

    @ViewBuilder
    private var manualAddSteps: some View {
        stepRow(1, "Open the \(permissionTitle) list:") {
            Button("Open System Settings") { manager.request(permission) }
                .buttonStyle(.borderedProminent)
                .applyingPermissionPilotTint(tint)
        }
        stepRow(2, "If \(appName) isn’t listed, add it — drag its icon in, or click + there and pick it:") {
            HStack(spacing: PPDesign.s16) {
                draggableIcon
                Button("Reveal in Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting([appURL])
                }
            }
        }
    }

    @ViewBuilder
    private var promptSteps: some View {
        stepRow(1, "Request access — macOS will ask:") {
            Button("Allow Access…") { manager.request(permission) }
                .buttonStyle(.borderedProminent)
                .applyingPermissionPilotTint(tint)
        }
        stepRow(2, "Or manage it in Settings:") {
            Button("Open System Settings") { manager.openSettings(for: permission) }
        }
    }

    // MARK: Pieces

    private func stepRow<Content: View>(
        _ number: Int,
        _ text: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: PPDesign.s8) {
            HStack(alignment: .firstTextBaseline, spacing: PPDesign.s8) {
                badge(number)
                Text(text)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            content()
                .padding(.leading, 26) // align under the step text, past the badge
        }
    }

    private func badge(_ number: Int) -> some View {
        Text("\(number)")
            .font(.caption.weight(.bold))
            .foregroundStyle(.secondary)
            .frame(width: 18, height: 18)
            .background(Circle().fill(Color.primary.opacity(0.08)))
    }

    private var draggableIcon: some View {
        VStack(spacing: PPDesign.s4) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: appURL.path))
                .resizable()
                .frame(width: 48, height: 48)
                .overlay(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [4]))
                        .foregroundStyle(.secondary)
                        .opacity(0.55)
                )
                .onDrag { NSItemProvider(contentsOf: appURL) ?? NSItemProvider() }
            Text("drag \(appName)")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .help("Drag into the \(permissionTitle) list in System Settings")
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(appName) icon. Drag it into the System Settings list.")
    }
}

extension Bundle {
    /// Best-effort app display name for host-facing copy.
    public var permissionPilotAppName: String {
        (object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? ProcessInfo.processInfo.processName
    }
}
