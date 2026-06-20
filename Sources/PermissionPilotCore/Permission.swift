import Foundation

/// A macOS system permission that a locally-distributed app may need.
///
/// These permissions cannot be granted programmatically — the user must flip a
/// toggle in System Settings. PermissionPilot detects status, prompts where the
/// OS allows, and deep-links to the exact pane otherwise.
///
/// Cases split into two groups: ones the engine fully supports today
/// (``isImplemented`` == `true`) and ones reserved for the roadmap, surfaced in
/// the UI as "Coming soon" (``isImplemented`` == `false`).
public enum Permission: String, CaseIterable, Identifiable, Hashable, Sendable {
    // MARK: Implemented
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

    // MARK: Coming soon (roadmap — shown disabled in the UI)
    case bluetooth
    case location
    case calendars
    case contacts
    case reminders
    case photos
    case notifications
    case speechRecognition
    case automation
    case localNetwork

    public var id: String { rawValue }

    /// Whether the engine fully supports detecting/requesting this permission yet.
    /// `false` cases render as disabled "Coming soon" in the UI.
    public var isImplemented: Bool {
        switch self {
        case .accessibility, .screenRecording, .inputMonitoring,
             .fullDiskAccess, .camera, .microphone:
            return true
        default:
            return false
        }
    }

    /// The permissions the engine supports today, in declaration order.
    public static var implemented: [Permission] { allCases.filter(\.isImplemented) }

    /// The roadmap permissions, shown as "Coming soon".
    public static var comingSoon: [Permission] { allCases.filter { !$0.isImplemented } }
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
        case .bluetooth:
            return PermissionInfo(
                title: "Bluetooth",
                reason: "Discover and connect to nearby Bluetooth devices.",
                systemImage: "antenna.radiowaves.left.and.right"
            )
        case .location:
            return PermissionInfo(
                title: "Location",
                reason: "Access your location.",
                systemImage: "location"
            )
        case .calendars:
            return PermissionInfo(
                title: "Calendars",
                reason: "Read and write your calendar events.",
                systemImage: "calendar"
            )
        case .contacts:
            return PermissionInfo(
                title: "Contacts",
                reason: "Access your contacts.",
                systemImage: "person.crop.circle"
            )
        case .reminders:
            return PermissionInfo(
                title: "Reminders",
                reason: "Read and write your reminders.",
                systemImage: "list.bullet"
            )
        case .photos:
            return PermissionInfo(
                title: "Photos",
                reason: "Access your photo library.",
                systemImage: "photo.on.rectangle"
            )
        case .notifications:
            return PermissionInfo(
                title: "Notifications",
                reason: "Send you notifications.",
                systemImage: "bell"
            )
        case .speechRecognition:
            return PermissionInfo(
                title: "Speech Recognition",
                reason: "Transcribe your speech.",
                systemImage: "waveform"
            )
        case .automation:
            return PermissionInfo(
                title: "Automation",
                reason: "Control other apps via Apple Events.",
                systemImage: "gearshape.2"
            )
        case .localNetwork:
            return PermissionInfo(
                title: "Local Network",
                reason: "Find and connect to devices on your local network.",
                systemImage: "network"
            )
        }
    }

    /// The `Privacy_*` anchor appended to the System Settings deep-link.
    /// Empty for permissions without a stable anchor (the UI hides the deep-link).
    public var settingsAnchor: String {
        switch self {
        case .accessibility:     return "Privacy_Accessibility"
        case .screenRecording:   return "Privacy_ScreenCapture"
        case .inputMonitoring:   return "Privacy_ListenEvent"
        case .fullDiskAccess:    return "Privacy_AllFiles"
        case .camera:            return "Privacy_Camera"
        case .microphone:        return "Privacy_Microphone"
        case .bluetooth:         return "Privacy_Bluetooth"
        case .location:          return "Privacy_LocationServices"
        case .calendars:         return "Privacy_Calendars"
        case .contacts:          return "Privacy_Contacts"
        case .reminders:         return "Privacy_Reminders"
        case .photos:            return "Privacy_Photos"
        case .notifications:     return ""
        case .speechRecognition: return "Privacy_SpeechRecognition"
        case .automation:        return "Privacy_Automation"
        case .localNetwork:      return "Privacy_LocalNetwork"
        }
    }

    /// Whether the OS can show a real consent prompt in-app.
    ///
    /// `false` for Full Disk Access (deep-link only) and for any not-yet-
    /// implemented permission.
    public var canPromptInApp: Bool {
        guard isImplemented else { return false }
        return self != .fullDiskAccess
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
    /// without them. The roadmap keys are documented here for when each ships.
    public var requiredInfoPlistKey: String? {
        switch self {
        case .camera:            return "NSCameraUsageDescription"
        case .microphone:        return "NSMicrophoneUsageDescription"
        case .accessibility:     return "NSAccessibilityUsageDescription" // optional
        case .bluetooth:         return "NSBluetoothAlwaysUsageDescription"
        case .location:          return "NSLocationWhenInUseUsageDescription"
        case .calendars:         return "NSCalendarsFullAccessUsageDescription"
        case .contacts:          return "NSContactsUsageDescription"
        case .reminders:         return "NSRemindersFullAccessUsageDescription"
        case .photos:            return "NSPhotoLibraryUsageDescription"
        case .speechRecognition: return "NSSpeechRecognitionUsageDescription"
        case .automation:        return "NSAppleEventsUsageDescription"
        case .localNetwork:      return "NSLocalNetworkUsageDescription"
        default:                 return nil
        }
    }
}
