// PermissionPilot — full onboarding wizard (depends on Core + UI).
//
// The top-level product. Importing `PermissionPilot` also re-exports
// `PermissionPilotCore` and `PermissionPilotUI`, so a single import gives you
// the model, manager, components, and wizard.

import SwiftUI
import AppKit

@_exported import PermissionPilotCore
@_exported import PermissionPilotUI

/// Top-level entry point and onboarding-state helpers.
public enum PermissionPilot {

    /// SDK version.
    public static let version = PermissionPilotCore.version

    // MARK: Onboarding state

    /// Whether first-run onboarding has been completed.
    public static var hasCompletedOnboarding: Bool {
        OnboardingState.hasCompleted
    }

    /// Marks onboarding complete.
    public static func markOnboardingCompleted() {
        OnboardingState.markCompleted()
    }

    /// Clears the completion flag so the wizard shows again (e.g. a
    /// "Re-run setup" item in your app's settings).
    public static func resetOnboarding() {
        OnboardingState.reset()
    }

    // MARK: Presentation

    /// Presents the onboarding wizard in a managed, centered `NSWindow`.
    ///
    /// - Parameters:
    ///   - manager: The permission engine declaring required/optional permissions.
    ///   - configuration: Host branding + copy.
    ///   - onFinish: Called after the user taps Finish (completion is persisted).
    /// - Returns: The presenter, which you may keep to `close()` early.
    @MainActor
    @discardableResult
    public static func presentOnboarding(
        manager: PermissionManager,
        configuration: OnboardingConfiguration,
        onFinish: (() -> Void)? = nil
    ) -> OnboardingPresenter {
        OnboardingPresenter.present(
            manager: manager,
            configuration: configuration,
            onFinish: onFinish
        )
    }
}
