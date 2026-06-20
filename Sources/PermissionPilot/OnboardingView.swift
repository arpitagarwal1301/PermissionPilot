import SwiftUI
import AppKit
import PermissionPilotCore
import PermissionPilotUI

/// The full first-run onboarding wizard: **welcome → permissions → done**, with
/// a step indicator, the live permission checklist, auto re-check / auto-advance,
/// and a relaunch affordance where macOS requires one.
///
/// Embed it directly in your own window/sheet, or present it in a managed window
/// via ``PermissionPilot/presentOnboarding(manager:configuration:onFinish:)``.
public struct OnboardingView: View {

    /// The wizard steps.
    public enum Step: Int, CaseIterable {
        case welcome, permissions, done
        var index: Int { rawValue }
    }

    @ObservedObject private var manager: PermissionManager
    private let configuration: OnboardingConfiguration
    private let onFinish: () -> Void

    @State private var step: Step
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        manager: PermissionManager,
        configuration: OnboardingConfiguration,
        initialStep: Step = .welcome,
        onFinish: @escaping () -> Void = {}
    ) {
        self.manager = manager
        self.configuration = configuration
        self.onFinish = onFinish
        _step = State(initialValue: initialStep)
    }

    public var body: some View {
        VStack(spacing: 0) {
            // The approved screens show step dots only on the permissions step.
            if step == .permissions {
                StepIndicator(current: step.index, total: Step.allCases.count)
                    .padding(.top, PPDesign.s16)
                    .padding(.bottom, PPDesign.s8)
            }

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            if step == .permissions {
                bottomBar
            }
        }
        .frame(minWidth: PPDesign.windowWidth, minHeight: PPDesign.windowHeight)
        .background(PPColor.window)
        .permissionPilotTint(configuration.tint)
        .tint(configuration.tint ?? .accentColor)
        .onAppear { manager.refresh() }
        .onChange(of: manager.allRequiredGranted) { granted in
            autoAdvanceIfReady(granted)
        }
    }

    // MARK: Steps

    @ViewBuilder
    private var content: some View {
        switch step {
        case .welcome:     welcomeStep
        case .permissions: permissionsStep
        case .done:        doneStep
        }
    }

    private var welcomeStep: some View {
        VStack(spacing: PPDesign.s20) {
            appIconSlot
            VStack(spacing: PPDesign.s12) {
                Text(configuration.resolvedWelcomeHeadline)
                    .font(.title).fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                Text(configuration.resolvedWelcomeSubtitle)
                    .font(.callout).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 420)
            }
            Button("Get Started") { go(to: .permissions) }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.top, PPDesign.s8)
        }
        .padding(PPDesign.s32)
    }

    private var permissionsStep: some View {
        ScrollView {
            VStack(spacing: PPDesign.s16) {
                PermissionChecklist(
                    manager: manager,
                    reasonOverrides: configuration.reasons
                )
                if showsScreenRecordingPrewarning {
                    Label(
                        "macOS may ask you to re-confirm Screen Recording periodically — that's expected.",
                        systemImage: "info.circle"
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: PPDesign.cardWidth, alignment: .leading)
                }
                if manager.needsRelaunch {
                    relaunchBanner
                }
            }
            .padding(.horizontal, PPDesign.s24)
            .padding(.vertical, PPDesign.s12)
            .frame(maxWidth: .infinity)
        }
        // onChange fires only on transitions; also check on entry so re-runs with
        // grants already in place auto-advance instead of stalling on the checklist.
        .onAppear {
            manager.refresh()
            autoAdvanceIfReady(manager.allRequiredGranted)
        }
    }

    private var doneStep: some View {
        VStack(spacing: PPDesign.s20) {
            successCheck
            VStack(spacing: PPDesign.s12) {
                Text(configuration.doneTitle)
                    .font(.title).fontWeight(.semibold)
                    .accessibilityAddTraits(.isHeader)
                Text(configuration.resolvedDoneSubtitle)
                    .font(.callout).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 420)
            }
            Button("Finish") { finish() }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        }
        .padding(PPDesign.s32)
    }

    // MARK: Pieces

    @ViewBuilder
    private var appIconSlot: some View {
        let shape = RoundedRectangle(cornerRadius: PPDesign.appIconRadius, style: .continuous)
        if let icon = configuration.appIcon {
            icon
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: PPDesign.appIconSlot, height: PPDesign.appIconSlot)
                .clipShape(shape)
                .accessibilityHidden(true)
        } else {
            shape
                .fill(PPColor.iconTile(scheme))
                .frame(width: PPDesign.appIconSlot, height: PPDesign.appIconSlot)
                .overlay(
                    Image(systemName: "photo")
                        .font(.system(size: 28, weight: .regular))
                        .foregroundStyle(.secondary)
                )
                .accessibilityHidden(true)
        }
    }

    private var successCheck: some View {
        ZStack {
            Circle()
                .fill(PPColor.granted)
                .frame(width: 96, height: 96)
                .shadow(color: PPColor.granted.opacity(0.5), radius: 24)
            Image(systemName: "checkmark")
                .font(.system(size: 44, weight: .bold))
                .foregroundStyle(PPColor.window) // knockout: adapts to light/dark
        }
        .accessibilityHidden(true)
    }

    private var relaunchBanner: some View {
        HStack(spacing: PPDesign.s8) {
            Image(systemName: "arrow.clockwise.circle")
                .foregroundStyle(.secondary)
            Text("Some changes take effect after you quit and reopen.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer(minLength: PPDesign.s12)
            Button("Quit & Reopen") { manager.quitAndReopen() }
                .controlSize(.small)
        }
        .padding(.horizontal, PPDesign.s12)
        .padding(.vertical, PPDesign.s8)
        .frame(maxWidth: PPDesign.cardWidth)
        .background(
            RoundedRectangle(cornerRadius: PPDesign.iconTileRadius, style: .continuous)
                .fill(PPColor.iconTile(scheme))
        )
    }

    // The spec's "Skip for optional steps" is satisfied here without a Skip
    // button: optional permissions live inline in the single checklist, and
    // Continue is gated solely on `allRequiredGranted` — never on optional grants,
    // so finishing is never blocked on an optional permission.
    private var bottomBar: some View {
        HStack {
            Button("Back") { go(to: .welcome) }
                .buttonStyle(.bordered)
                .controlSize(.large)
            Spacer()
            Button("Continue") { go(to: .done) }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!manager.allRequiredGranted)
        }
        .padding(.horizontal, PPDesign.s32)
        .padding(.top, PPDesign.s12)
        .padding(.bottom, PPDesign.s24)
    }

    // MARK: Logic

    private var showsScreenRecordingPrewarning: Bool {
        configuration.showsScreenRecordingPrewarning
            && manager.allPermissions.contains(.screenRecording)
            && manager.status(for: .screenRecording) != .granted
    }

    private func go(to target: Step) {
        if reduceMotion {
            step = target
        } else {
            withAnimation(.easeInOut(duration: 0.25)) { step = target }
        }
    }

    private func autoAdvanceIfReady(_ granted: Bool) {
        guard granted, step == .permissions else { return }
        if reduceMotion {
            step = .done
            announceDone()
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                if step == .permissions {
                    go(to: .done)
                    announceDone()
                }
            }
        }
    }

    /// VoiceOver announcement for the one transition that happens with no user
    /// action — auto-advancing to the Done step. Uses AppKit's `NSAccessibility`
    /// (the SwiftUI `AccessibilityNotification` API is macOS 14+).
    private func announceDone() {
        let element: Any = NSApp.keyWindow ?? NSApplication.shared
        NSAccessibility.post(
            element: element,
            notification: .announcementRequested,
            userInfo: [
                .announcement: "All set. \(configuration.doneTitle)",
                .priority: NSAccessibilityPriorityLevel.high.rawValue,
            ]
        )
    }

    private func finish() {
        OnboardingState.markCompleted()
        onFinish()
    }
}
