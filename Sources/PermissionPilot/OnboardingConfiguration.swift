import SwiftUI
import PermissionPilotCore

/// Host customization for the onboarding wizard. The SDK ships **no branding of
/// its own** — every visible string, the icon, and the accent come from here,
/// each with a sensible default derived from `appName`.
public struct OnboardingConfiguration {
    /// The host app's name. Drives default copy and the window title.
    public var appName: String
    /// The host app's icon. `nil` shows a neutral placeholder slot.
    public var appIcon: Image?

    /// Welcome headline. Defaults to "Welcome to \(appName)".
    public var welcomeHeadline: String?
    /// Welcome subtitle. Defaults to a one-line "needs a few permissions" line.
    public var welcomeSubtitle: String?

    /// Done-screen title. Defaults to "You're all set".
    public var doneTitle: String
    /// Done-screen subtitle. Defaults to an "everything it needs" line.
    public var doneSubtitle: String?

    /// Optional accent override. `nil` follows the system accent.
    public var tint: Color?

    /// Per-permission "why we need this" reason overrides.
    public var reasons: [Permission: String]

    /// When `true` (default), shows a short pre-warning that macOS may re-ask for
    /// Screen Recording periodically (the Sequoia recurring prompt).
    public var showsScreenRecordingPrewarning: Bool

    public init(
        appName: String,
        appIcon: Image? = nil,
        welcomeHeadline: String? = nil,
        welcomeSubtitle: String? = nil,
        doneTitle: String? = nil,
        doneSubtitle: String? = nil,
        tint: Color? = nil,
        reasons: [Permission: String] = [:],
        showsScreenRecordingPrewarning: Bool = true
    ) {
        self.appName = appName
        self.appIcon = appIcon
        self.welcomeHeadline = welcomeHeadline
        self.welcomeSubtitle = welcomeSubtitle
        self.doneTitle = doneTitle ?? ppLocalized("onboarding.done.title")
        self.doneSubtitle = doneSubtitle
        self.tint = tint
        self.reasons = reasons
        self.showsScreenRecordingPrewarning = showsScreenRecordingPrewarning
    }

    // MARK: Resolved copy

    var resolvedWelcomeHeadline: String {
        welcomeHeadline ?? ppFormat("onboarding.welcome.headline", appName)
    }

    var resolvedWelcomeSubtitle: String {
        welcomeSubtitle ?? ppFormat("onboarding.welcome.subtitle", appName)
    }

    var resolvedDoneSubtitle: String {
        doneSubtitle ?? ppFormat("onboarding.done.subtitle", appName)
    }
}
