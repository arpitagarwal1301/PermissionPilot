import Foundation

/// A macOS system permission that a locally-distributed app may need.
///
/// These permissions cannot be granted programmatically — the user must flip a
/// toggle in System Settings. PermissionPilot detects status, prompts where the
/// OS allows, and deep-links to the exact pane otherwise.
///
/// Every case is fully supported (``isImplemented`` == `true`). Permissions fall
/// into three tiers by how they're authorized:
/// - **Prompt-based** — a real in-app consent prompt (camera, microphone,
///   location, contacts, calendars, reminders, photos, speechRecognition,
///   bluetooth, notifications) plus the three system-prompt panes (accessibility,
///   screenRecording, inputMonitoring).
/// - **Deep-link-only** — macOS exposes no honest in-app prompt/detection, so the
///   flow deep-links to the exact System Settings pane: fullDiskAccess (status via
///   heuristic), automation (per-target Apple Events), localNetwork (no status API).
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
    /// Discover/connect Bluetooth devices (`CBManager.authorization`).
    case bluetooth
    /// Access location (`CLLocationManager.authorizationStatus`).
    case location
    /// Read/write calendar events (`EKEventStore`, entity `.event`).
    case calendars
    /// Access contacts (`CNContactStore.authorizationStatus(for: .contacts)`).
    case contacts
    /// Read/write reminders (`EKEventStore`, entity `.reminder`).
    case reminders
    /// Access the photo library (`PHPhotoLibrary.authorizationStatus(for: .readWrite)`).
    case photos
    /// Post user notifications (`UNUserNotificationCenter`; status is async-only).
    case notifications
    /// Transcribe speech (`SFSpeechRecognizer.authorizationStatus`).
    case speechRecognition
    /// Control other apps via Apple Events (per-target; deep-link only).
    case automation
    /// Find/connect devices on the local network (no status API; deep-link only).
    case localNetwork

    public var id: String { rawValue }

    /// Whether the engine fully supports detecting/requesting this permission.
    /// All cases are implemented today.
    public var isImplemented: Bool { true }

    /// The permissions the engine supports today, in declaration order.
    public static var implemented: [Permission] { allCases.filter(\.isImplemented) }

    /// The roadmap permissions, shown as "Coming soon". Empty now that every
    /// case is implemented; retained so hosts that referenced it still compile.
    public static var comingSoon: [Permission] { allCases.filter { !$0.isImplemented } }
}

// MARK: - Metadata

extension Permission {
    /// The default human-facing descriptor (title, reason, SF Symbol).
    ///
    /// Hosts may override the reason (and title) via `infoOverrides` on
    /// ``PermissionManager`` or the wizard configuration.
    public var defaultInfo: PermissionInfo {
        PermissionInfo(
            title: ppLocalized("permission.\(rawValue).title"),
            reason: ppLocalized("permission.\(rawValue).reason"),
            systemImage: systemImage
        )
    }

    /// The SF Symbol shown for this permission.
    private var systemImage: String {
        switch self {
        case .accessibility:     return "accessibility"
        case .screenRecording:   return "display"
        case .inputMonitoring:   return "keyboard"
        case .fullDiskAccess:    return "internaldrive"
        case .camera:            return "camera"
        case .microphone:        return "mic"
        case .bluetooth:         return "antenna.radiowaves.left.and.right"
        case .location:          return "location"
        case .calendars:         return "calendar"
        case .contacts:          return "person.crop.circle"
        case .reminders:         return "list.bullet"
        case .photos:            return "photo.on.rectangle"
        case .notifications:     return "bell"
        case .speechRecognition: return "waveform"
        case .automation:        return "gearshape.2"
        case .localNetwork:      return "network"
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
    /// `false` for the deep-link-only tier — Full Disk Access (heuristic status),
    /// Automation (per-target Apple Events), and Local Network (no status API) —
    /// where there is no honest in-app prompt and the flow opens System Settings.
    public var canPromptInApp: Bool {
        guard isImplemented else { return false }
        return ![.fullDiskAccess, .automation, .localNetwork].contains(self)
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

    /// The Info.plist usage-description key whose **absence crashes the host** when
    /// this permission is requested — i.e. the mandatory key for the in-app prompt.
    ///
    /// Returned only for prompt-based privacy permissions (camera, microphone,
    /// bluetooth, location, calendars, contacts, reminders, photos, speech). The
    /// crash-guard in ``PermissionProbe`` checks this before prompting.
    ///
    /// `nil` for permissions that don't crash without a key:
    /// - `accessibility` — `NSAccessibilityUsageDescription` is informational only,
    ///   not enforced by TCC (no crash); request uses `AXIsProcessTrusted`.
    /// - `screenRecording` / `inputMonitoring` — no usage string.
    /// - `notifications` — `requestAuthorization` needs no Info.plist key.
    /// - `fullDiskAccess` / `automation` / `localNetwork` — deep-link only, never
    ///   trigger an API that would crash (`automation` would use
    ///   `NSAppleEventsUsageDescription`, `localNetwork` `NSLocalNetworkUsageDescription`
    ///   only when actually driving those APIs — out of scope for the deep-link flow).
    ///
    /// Calendars/Reminders are version-sensitive: macOS 14+ requires the
    /// `…FullAccess…` key (used by `requestFullAccessTo…`), earlier the legacy key.
    public var requiredInfoPlistKey: String? {
        switch self {
        case .camera:            return "NSCameraUsageDescription"
        case .microphone:        return "NSMicrophoneUsageDescription"
        case .bluetooth:         return "NSBluetoothAlwaysUsageDescription"
        case .location:          return "NSLocationWhenInUseUsageDescription"
        case .contacts:          return "NSContactsUsageDescription"
        case .photos:            return "NSPhotoLibraryUsageDescription"
        case .speechRecognition: return "NSSpeechRecognitionUsageDescription"
        case .calendars:
            if #available(macOS 14.0, *) { return "NSCalendarsFullAccessUsageDescription" }
            return "NSCalendarsUsageDescription"
        case .reminders:
            if #available(macOS 14.0, *) { return "NSRemindersFullAccessUsageDescription" }
            return "NSRemindersUsageDescription"
        default:                 return nil
        }
    }

    /// Whether the user can add this app to the permission's list **manually**
    /// (the System Settings pane has a `+` / accepts a dragged app). True for
    /// Accessibility, Screen Recording, Input Monitoring, and Full Disk Access —
    /// these are where an app may need to be added before it can be toggled on.
    ///
    /// Camera/Microphone (and similar) can't be added manually: the app only
    /// appears in their list after it requests access via the system prompt.
    public var supportsManualAdd: Bool {
        switch self {
        case .accessibility, .screenRecording, .inputMonitoring, .fullDiskAccess:
            return true
        default:
            return false
        }
    }

    /// Official Apple documentation for this permission (shown via an info icon on
    /// "coming soon" items so developers can read how to implement / configure it).
    public var documentationURL: URL? {
        let base = "https://developer.apple.com/documentation/"
        let path: String?
        switch self {
        case .bluetooth:         path = "corebluetooth"
        case .location:          path = "corelocation"
        case .calendars:         path = "eventkit"
        case .contacts:          path = "contacts"
        case .reminders:         path = "eventkit"
        case .photos:            path = "photokit"
        case .notifications:     path = "usernotifications"
        case .speechRecognition: path = "speech"
        case .automation:        path = "applicationservices"
        case .localNetwork:      path = "network"
        default:                 path = nil
        }
        return path.flatMap { URL(string: base + $0) }
    }
}
