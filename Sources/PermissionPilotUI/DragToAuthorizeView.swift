import SwiftUI
import AppKit
import PermissionPilotCore

/// A guided "how to grant this" helper, shown from a permission's **Enable**.
///
/// It adapts to the permission:
/// - **Manual-add panes** (Accessibility, Screen Recording, Input Monitoring,
///   Full Disk Access): open the list — which also adds the app to it where
///   macOS allows — then switch it on; drag the app icon in, or use **+**, if
///   it isn't listed.
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

    /// Manual-add panes whose request API also adds the app to the list
    /// (switched off) — there the user normally just flips the switch, and
    /// dragging is the fallback. Full Disk Access has no such API.
    private var listedByRequest: Bool { permission.supportsManualAdd && permission.canPromptInApp }

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
        if listedByRequest {
            return ppFormat("drag.subtitle.listed", appName)
        } else if permission.supportsManualAdd {
            return ppFormat("drag.subtitle.manualAdd", appName)
        } else if permission.canPromptInApp {
            return ppLocalized("drag.subtitle.prompt")
        } else {
            return ppFormat("drag.subtitle.deepLink", appName)
        }
    }

    private var footerNote: String {
        if listedByRequest {
            return ppFormat("drag.footer.listed", appName)
        } else if permission.supportsManualAdd {
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
        if manager.systemPromptShowing == permission {
            // macOS' first-time prompt is up; its button opens the pane AND
            // dismisses it — opening the pane from here would strand it.
            Label(ppFormat("drag.systemPrompt", appName), systemImage: "hand.point.up.left.fill")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(PPDesign.s12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill((tint ?? .accentColor).opacity(0.14))
                )
        }
        stepRow(1, listedByRequest
                    ? ppFormat("drag.step.switchOn", appName, permissionTitle)
                    : ppFormat("drag.step.openList", permissionTitle)) {
            // request() registers the app in the list (Accessibility, Screen
            // Recording, Input Monitoring) so the user only flips a switch, and
            // opens the pane unless macOS' first-time prompt does it instead.
            // For Full Disk Access it simply opens the pane. Disabled while that
            // prompt is up: opening the pane from here would strand it.
            Button(ppLocalized("action.openSettings")) { manager.request(permission) }
                .buttonStyle(.borderedProminent)
                .applyingPermissionPilotTint(tint)
                .disabled(manager.systemPromptShowing == permission)
        }
        stepRow(2, ppFormat(listedByRequest ? "drag.step.dragFallback" : "drag.step.drag", appName)) {
            HStack(alignment: .center, spacing: PPDesign.s16) {
                dragZone
                Button(ppLocalized("action.revealInFinder")) { FinderReveal.reveal(appURL) }
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
    /// with a "Drag me" cue, a grab cursor (set by the drag source's cursor
    /// rect), and a gentle pulse (reduce-motion safe).
    private var dragZone: some View {
        let accent = tint ?? .accentColor
        return VStack(spacing: PPDesign.s8) {
            // AppKit file drag, not SwiftUI .onDrag — see AppBundleDragSource.
            AppBundleDragSource(appURL: appURL)
                .frame(width: 58, height: 58)
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
