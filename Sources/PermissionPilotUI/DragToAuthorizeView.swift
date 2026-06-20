import SwiftUI
import AppKit
import PermissionPilotCore

/// A guided helper for permissions that have **no programmatic request API** —
/// most notably Full Disk Access, where the user must add the app to the
/// System Settings list themselves.
///
/// It spells out the two steps, offers both ways to add the app (drag its icon
/// in, or use the **+** button), and covers the "already listed" case. Built
/// entirely on AppKit/SwiftUI drag APIs — no third-party code.
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
                Text("macOS can’t ask for this one — you add \(appName) to the list yourself.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

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

            Divider()

            Label("Already in the list? Just switch it on.", systemImage: "info.circle")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(PPDesign.s20)
        .frame(width: 420)
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
