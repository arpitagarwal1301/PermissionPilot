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

    /// The steps actually shown, in order, honoring the configuration's
    /// `showsWelcomeStep` / `showsDoneStep`. Permissions is always present.
    static func activeSteps(for configuration: OnboardingConfiguration) -> [Step] {
        var steps: [Step] = []
        if configuration.showsWelcomeStep { steps.append(.welcome) }
        steps.append(.permissions)
        if configuration.showsDoneStep { steps.append(.done) }
        return steps
    }

    private var steps: [Step] { Self.activeSteps(for: configuration) }

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
        // Start at the requested step if it's shown; otherwise the first shown
        // step (e.g. permissions when the welcome step is omitted).
        let active = Self.activeSteps(for: configuration)
        _step = State(initialValue: active.contains(initialStep) ? initialStep : (active.first ?? .permissions))
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Step dots show only on the permissions step, and only when there's
            // more than one step to indicate progress through.
            if step == .permissions, steps.count > 1 {
                StepIndicator(current: steps.firstIndex(of: .permissions) ?? 0, total: steps.count)
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
        .preferredColorScheme(configuration.colorScheme)
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
            Button(ppLocalized("onboarding.getStarted")) { go(to: .permissions) }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.top, PPDesign.s8)
        }
        .padding(PPDesign.s32)
    }

    private var permissionsStep: some View {
        // No outer ScrollView — PermissionsView scrolls its rows/tiles internally
        // with a pinned header; the prewarning note stays below it.
        VStack(spacing: PPDesign.s12) {
            PermissionsView(
                manager: manager,
                title: ppLocalized("onboarding.permissionsTitle"),
                reasonOverrides: configuration.reasons
            )
            .frame(maxHeight: .infinity)
            if showsScreenRecordingPrewarning {
                Label(
                    ppLocalized("onboarding.screenRecordingPrewarning"),
                    systemImage: "info.circle"
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: PPDesign.cardWidth, alignment: .leading)
            }
        }
        .padding(.horizontal, PPDesign.s24)
        .padding(.vertical, PPDesign.s12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
            Button(ppLocalized("onboarding.finish")) { finish() }
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

    // The spec's "Skip for optional steps" is satisfied here without a Skip
    // button: optional permissions live inline in the single checklist, and
    // Continue is gated solely on `allRequiredGranted` — never on optional grants,
    // so finishing is never blocked on an optional permission.
    private var bottomBar: some View {
        HStack {
            // Back only when there's a welcome step to return to.
            if configuration.showsWelcomeStep {
                Button(ppLocalized("onboarding.back")) { go(to: .welcome) }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
            }
            Spacer()
            Button(ppLocalized("onboarding.continue")) { advanceFromPermissions() }
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

    /// Leaves the permissions step: to the done screen if shown, else finishes
    /// straight away (handing control back to the host's own flow).
    private func advanceFromPermissions() {
        if configuration.showsDoneStep {
            go(to: .done)
        } else {
            finish()
        }
    }

    private func autoAdvanceIfReady(_ granted: Bool) {
        // Only auto-advance into a done screen. With the done step omitted we let
        // the user tap Continue rather than closing the window from under them.
        guard granted, step == .permissions, configuration.showsDoneStep else { return }
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
                .announcement: ppFormat("onboarding.announceDone", configuration.doneTitle),
                .priority: NSAccessibilityPriorityLevel.high.rawValue,
            ]
        )
    }

    private func finish() {
        OnboardingState.markCompleted()
        onFinish()
    }
}
