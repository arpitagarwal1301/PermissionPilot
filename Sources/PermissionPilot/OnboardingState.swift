import Foundation
import SwiftUI

/// Persists whether first-run onboarding has been completed, so hosts can show
/// the wizard once and re-open it later from settings.
///
/// Backed by `UserDefaults.standard`. SwiftUI views can bind to the same key
/// via `@AppStorage(OnboardingState.completedKey)`.
public enum OnboardingState {
    /// The `UserDefaults` / `@AppStorage` key for the completion flag.
    public static let completedKey = "permissionPilot.onboardingCompleted"

    /// Whether onboarding has been marked complete.
    public static var hasCompleted: Bool {
        UserDefaults.standard.bool(forKey: completedKey)
    }

    /// Marks onboarding complete (called automatically when the user taps Finish).
    public static func markCompleted() {
        UserDefaults.standard.set(true, forKey: completedKey)
    }

    /// Clears the completion flag so the wizard shows again.
    public static func reset() {
        UserDefaults.standard.set(false, forKey: completedKey)
    }
}
