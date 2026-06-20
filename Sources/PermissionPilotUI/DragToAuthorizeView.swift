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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

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
                Text(ppFormat("drag.title", appName, permissionTitle))
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if permission.supportsManualAdd {
                manualAddSteps
            } else if permission.canPromptInApp {
                promptSteps
            } else {
                deepLinkSteps
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
        if permission.supportsManualAdd {
            return ppFormat("drag.subtitle.manualAdd", appName)
        } else if permission.canPromptInApp {
            return ppLocalized("drag.subtitle.prompt")
        } else {
            return ppFormat("drag.subtitle.deepLink", appName)
        }
    }

    private var footerNote: String {
        if permission.supportsManualAdd {
            return ppLocalized("drag.footer.manualAdd")
        } else if permission.canPromptInApp {
            return ppFormat("drag.footer.prompt", appName, permissionTitle)
        } else {
            return ppFormat("drag.footer.deepLink", appName, permissionTitle)
        }
    }

    // MARK: Step groups

    @ViewBuilder
    private var manualAddSteps: some View {
        stepRow(1, ppFormat("drag.step.openList", permissionTitle)) {
            Button(ppLocalized("action.openSettings")) { manager.request(permission) }
                .buttonStyle(.borderedProminent)
                .applyingPermissionPilotTint(tint)
        }
        stepRow(2, ppFormat("drag.step.drag", appName)) {
            HStack(alignment: .center, spacing: PPDesign.s16) {
                dragZone
                Button(ppLocalized("action.revealInFinder")) {
                    NSWorkspace.shared.activateFileViewerSelecting([appURL])
                }
            }
        }
    }

    @ViewBuilder
    private var promptSteps: some View {
        VStack(alignment: .leading, spacing: PPDesign.s8) {
            Button(ppLocalized("action.allowAccess")) { manager.request(permission) }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
                .applyingPermissionPilotTint(tint)
            HStack(spacing: 4) {
                Text(ppLocalized("drag.alreadyDenied"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Button(ppLocalized("action.openSettings")) { manager.openSettings(for: permission) }
                    .buttonStyle(.link)
                    .font(.footnote)
            }
        }
    }

    /// Deep-link-only permissions (Automation, Local Network): macOS exposes no
    /// in-app prompt, so we send the user straight to the exact Settings pane.
    @ViewBuilder
    private var deepLinkSteps: some View {
        VStack(alignment: .leading, spacing: PPDesign.s8) {
            Button(ppLocalized("action.openSettings")) { manager.openSettings(for: permission) }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
                .applyingPermissionPilotTint(tint)
            Text(ppFormat("drag.deepLink.hint", appName, permissionTitle))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
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

    /// A prominent, obviously-draggable drop-zone: the app icon in a dashed box
    /// with a "Drag me" cue, a grab cursor, and a gentle pulse (reduce-motion safe).
    private var dragZone: some View {
        let accent = tint ?? .accentColor
        return VStack(spacing: PPDesign.s8) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: appURL.path))
                .resizable()
                .frame(width: 58, height: 58)
                .onDrag { NSItemProvider(contentsOf: appURL) ?? NSItemProvider() }
            Text(ppLocalized("drag.zone.label"))
                .font(.caption.weight(.bold))
                .foregroundStyle(accent)
        }
        .padding(.horizontal, PPDesign.s16)
        .padding(.vertical, PPDesign.s12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(accent.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(accent, style: StrokeStyle(lineWidth: 1.5, dash: [5]))
                .opacity(pulse ? 0.95 : 0.5)
        )
        .shadow(color: accent.opacity(pulse ? 0.28 : 0), radius: pulse ? 7 : 0)
        .onHover { inside in
            if inside { NSCursor.openHand.push() } else { NSCursor.pop() }
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
        .help(ppFormat("drag.zone.help", permissionTitle))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(ppFormat("drag.zone.a11y", appName))
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
