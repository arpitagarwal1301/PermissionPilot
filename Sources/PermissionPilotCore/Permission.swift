import Foundation

/// A macOS system permission that a locally-distributed app may need.
///
/// These permissions cannot be granted programmatically — the user must flip a
/// toggle in System Settings. PermissionPilot detects status, prompts where the
/// OS allows, and deep-links to the exact pane otherwise.
public enum Permission: String, CaseIterable, Identifiable, Hashable, Sendable {
    /// Control the Mac to automate actions / read on-screen UI (`AXIsProcessTrusted`).
    case accessibility
    /// Capture the screen (`CGPreflightScreenCaptureAccess`).
    case screenRecording
    /// Observe keyboard / pointer input (`IOHIDCheckAccess`).
    case inputMonitoring
    /// Read TCC-protected files across the disk (heuristic; deep-link only).
    case fullDiskAccess
    /// Use the camera (`AVCaptureDevice.authorizationStatus(for: .video)`).
    case camera
    /// Use the microphone (`AVCaptureDevice.authorizationStatus(for: .audio)`).
    case microphone

    public var id: String { rawValue }
}

// MARK: - Metadata

extension Permission {
    /// The default human-facing descriptor (title, reason, SF Symbol).
    ///
    /// Hosts may override the reason (and title) via `infoOverrides` on
    /// ``PermissionManager`` or the wizard configuration.
    public var defaultInfo: PermissionInfo {
        switch self {
        case .accessibility:
            return PermissionInfo(
                title: "Accessibility",
                reason: "Control your Mac to automate actions and read on-screen content.",
                systemImage: "accessibility"
            )
        case .screenRecording:
            return PermissionInfo(
                title: "Screen Recording",
                reason: "Capture your screen to share, record, or analyze what’s on it.",
                systemImage: "display"
            )
        case .inputMonitoring:
            return PermissionInfo(
                title: "Input Monitoring",
                reason: "Detect keyboard and pointer input for shortcuts and automation.",
                systemImage: "keyboard"
            )
        case .fullDiskAccess:
            return PermissionInfo(
                title: "Full Disk Access",
                reason: "Read files across your Mac that are normally protected.",
                systemImage: "internaldrive"
            )
        case .camera:
            return PermissionInfo(
                title: "Camera",
                reason: "Use your camera for video features.",
                systemImage: "camera"
            )
        case .microphone:
            return PermissionInfo(
                title: "Microphone",
                reason: "Use your microphone for audio features.",
                systemImage: "mic"
            )
        }
    }

    /// The `Privacy_*` anchor appended to the System Settings deep-link.
    public var settingsAnchor: String {
        switch self {
        case .accessibility:   return "Privacy_Accessibility"
        case .screenRecording: return "Privacy_ScreenCapture"
        case .inputMonitoring: return "Privacy_ListenEvent"
        case .fullDiskAccess:  return "Privacy_AllFiles"
        case .camera:          return "Privacy_Camera"
        case .microphone:      return "Privacy_Microphone"
        }
    }

    /// Whether the OS can show a real consent prompt in-app.
    ///
    /// When `false` (Full Disk Access), the only path is the System Settings
    /// deep-link — there is no programmatic request API.
    public var canPromptInApp: Bool {
        switch self {
        case .fullDiskAccess: return false
        default:              return true
        }
    }

    /// Whether granting this permission only takes effect after the app is quit
    /// and reopened.
    ///
    /// Input Monitoring (IOKit HID) and Screen Recording (CoreGraphics) both
    /// capture their authorization for the process's lifetime, so a mid-session
    /// grant needs a relaunch — macOS still enforces this on macOS 15+/26
    /// (verified empirically: the OS quits & relaunches the app on grant).
    /// Accessibility, by contrast, re-evaluates trust live and needs no relaunch.
    public var mayRequireRelaunch: Bool {
        switch self {
        case .inputMonitoring, .screenRecording:
            return true
        default:
            return false
        }
    }

    /// The Info.plist usage-description key required for this permission, if any.
    ///
    /// Camera/Microphone are **required** — the app crashes on first access
    /// without them. Accessibility's key is optional (customizes the prompt).
    public var requiredInfoPlistKey: String? {
        switch self {
        case .camera:        return "NSCameraUsageDescription"
        case .microphone:    return "NSMicrophoneUsageDescription"
        case .accessibility: return "NSAccessibilityUsageDescription" // optional
        default:             return nil
        }
    }
}
