import SwiftUI
import AppKit
import PermissionPilotCore

/// A guided helper for permissions that have **no programmatic request API** —
/// most notably Full Disk Access, where the user must add the app to the
/// System Settings list themselves.
///
/// It shows the app's icon as a **draggable** item plus short steps and quick
/// actions, so authorizing is one drag (or a "+") away. Built entirely on
/// AppKit/SwiftUI drag APIs — no third-party code.
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
            Text("Add \(appName) to \(permissionTitle)")
                .font(.headline)
                .foregroundStyle(.primary)

            HStack(alignment: .top, spacing: PPDesign.s16) {
                draggableIcon
                VStack(alignment: .leading, spacing: PPDesign.s8) {
                    step(1, "Click Open System Settings below.")
                    step(2, "Drag this icon into the list — or click + there and choose \(appName).")
                    step(3, "Turn its switch on.")
                }
            }

            HStack(spacing: PPDesign.s12) {
                Button("Open System Settings") { manager.openSettings(for: permission) }
                    .buttonStyle(.borderedProminent)
                    .applyingPermissionPilotTint(tint)
                Button("Reveal in Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting([appURL])
                }
            }
        }
        .padding(PPDesign.s20)
        .frame(width: 380)
    }

    private var draggableIcon: some View {
        VStack(spacing: PPDesign.s4) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: appURL.path))
                .resizable()
                .frame(width: 56, height: 56)
                .onDrag { NSItemProvider(contentsOf: appURL) ?? NSItemProvider() }
            Text("drag")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(appName) icon. Drag it into the System Settings list.")
    }

    private func step(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: PPDesign.s8) {
            Text("\(number)")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .frame(width: 18, height: 18)
                .background(Circle().fill(Color.primary.opacity(0.08)))
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
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
