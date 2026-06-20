import Foundation
import AppKit
import ApplicationServices
import CoreGraphics
import AVFoundation
import IOKit.hid
import Contacts
import EventKit
import Photos
import Speech

/// Low-level detection + request implementations, one per permission, built on
/// Apple framework APIs. Stateless; ``PermissionManager`` owns the published state.
/// Location, Bluetooth, and Notifications need long-lived OS objects / async APIs,
/// so they delegate to the `…Authorizer` singletons.
///
/// Most checks re-query the OS on every call. The exceptions are Screen Recording
/// (`CGPreflightScreenCaptureAccess()` can be process-cached) and Notifications
/// (async-only status, served from a cache). Pure status→`PermissionStatus`
/// mappings live in `PermissionStatusMapping.swift`.
enum PermissionProbe {

    // MARK: Detect

    static func status(for permission: Permission) -> PermissionStatus {
        switch permission {
        case .accessibility:     return accessibilityStatus()
        case .screenRecording:   return screenRecordingStatus()
        case .inputMonitoring:   return inputMonitoringStatus()
        case .fullDiskAccess:    return fullDiskAccessStatus()
        case .camera:            return mediaStatus(for: .video)
        case .microphone:        return mediaStatus(for: .audio)
        case .contacts:          return PermissionStatus.from(CNContactStore.authorizationStatus(for: .contacts))
        case .photos:            return PermissionStatus.from(PHPhotoLibrary.authorizationStatus(for: .readWrite))
        case .speechRecognition: return PermissionStatus.from(SFSpeechRecognizer.authorizationStatus())
        case .calendars:         return PermissionStatus.from(EKEventStore.authorizationStatus(for: .event))
        case .reminders:         return PermissionStatus.from(EKEventStore.authorizationStatus(for: .reminder))
        case .bluetooth:         return BluetoothAuthorizer.status
        case .location:          return LocationAuthorizer.shared.cachedStatus
        case .notifications:     return NotificationAuthorizer.shared.cachedStatus
        // Deep-link-only: no honest status API (per-target / Sequoia-only).
        case .automation, .localNetwork: return .unknown
        }
    }

    static func accessibilityStatus() -> PermissionStatus {
        // No notDetermined distinction is exposed; untrusted is treated as denied
        // (still actionable — the row offers "Enable").
        AXIsProcessTrusted() ? .granted : .denied
    }

    static func screenRecordingStatus() -> PermissionStatus {
        // CGPreflight may be process-cached; a mid-session grant can require a
        // relaunch before it reads true (see the type doc + mayRequireRelaunch).
        CGPreflightScreenCaptureAccess() ? .granted : .denied
    }

    static func inputMonitoringStatus() -> PermissionStatus {
        switch IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) {
        case kIOHIDAccessTypeGranted: return .granted
        case kIOHIDAccessTypeDenied:  return .denied
        case kIOHIDAccessTypeUnknown: return .notDetermined
        default:                      return .unknown
        }
    }

    static func mediaStatus(for mediaType: AVMediaType) -> PermissionStatus {
        PermissionStatus.from(AVCaptureDevice.authorizationStatus(for: mediaType))
    }

    /// Full Disk Access has no detection API. We probe by attempting to open a
    /// well-known TCC-protected file for reading — success implies FDA is granted.
    ///
    /// Approach credited to the MIT-licensed FullDiskAccess project
    /// (https://github.com/inket/FullDiskAccess), reimplemented here.
    static func fullDiskAccessStatus() -> PermissionStatus {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let candidates = [
            home.appendingPathComponent("Library/Application Support/com.apple.TCC/TCC.db"),
            home.appendingPathComponent("Library/Safari/CloudTabs.db"),
            URL(fileURLWithPath: "/Library/Application Support/com.apple.TCC/TCC.db"),
        ]
        for url in candidates where FileManager.default.fileExists(atPath: url.path) {
            if let handle = try? FileHandle(forReadingFrom: url) {
                try? handle.close()
                return .granted
            }
            // The protected file exists but cannot be opened → not yet authorized.
            return .denied
        }
        // None of the probe files exist on this system; cannot confirm.
        return .unknown
    }

    // MARK: Request

    /// Triggers the appropriate request path for `permission` and reports the
    /// resulting status on the main queue.
    ///
    /// - Camera/Microphone/Location/Contacts/Calendars/Reminders/Photos/Speech/
    ///   Bluetooth/Notifications show a real system prompt (where not already decided).
    /// - Accessibility shows the system "Open System Settings" prompt.
    /// - Screen Recording / Input Monitoring add the app and may prompt; the grant
    ///   often only applies after relaunch.
    /// - Full Disk Access / Automation / Local Network have no prompt — we deep-link.
    @MainActor
    static func request(_ permission: Permission, completion: @escaping (PermissionStatus) -> Void) {
        guard permission.isImplemented else { completion(.unknown); return }

        // Deep-link-only tier (Full Disk Access, Automation, Local Network): macOS
        // exposes no honest in-app prompt — open the exact pane, report best-effort.
        guard permission.canPromptInApp else {
            SystemSettingsLink.open(permission)
            completion(status(for: permission))
            return
        }

        // Prompt-based: requesting without the mandatory usage string TCC-kills the
        // host. Fail gracefully instead of crashing the app.
        guard ensureUsageDescription(for: permission, completion: completion) else { return }

        switch permission {
        case .accessibility:
            let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue()
            let options = [key: true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(options)
            completion(accessibilityStatus())

        case .screenRecording:
            // First call prompts + adds the app; afterward it's silent — so also
            // open the pane, ensuring "Enable" always leads somewhere visible.
            let granted = CGRequestScreenCaptureAccess()
            if !granted { SystemSettingsLink.open(.screenRecording) }
            completion(granted ? .granted : screenRecordingStatus())

        case .inputMonitoring:
            // Registers the app (and prompts the first time), but the grant only
            // applies after relaunch and later calls are silent — open the pane so
            // the toggle is obvious.
            let granted = IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
            if !granted { SystemSettingsLink.open(.inputMonitoring) }
            completion(granted ? .granted : inputMonitoringStatus())

        case .camera:            requestMedia(.camera, .video, completion: completion)
        case .microphone:        requestMedia(.microphone, .audio, completion: completion)
        case .contacts:          requestContacts(completion: completion)
        case .photos:            requestPhotos(completion: completion)
        case .speechRecognition: requestSpeech(completion: completion)
        case .calendars:         requestEventKit(.calendars, .event, completion: completion)
        case .reminders:         requestEventKit(.reminders, .reminder, completion: completion)
        case .location:          LocationAuthorizer.shared.request(completion)
        case .bluetooth:         BluetoothAuthorizer.shared.request(completion)
        case .notifications:     NotificationAuthorizer.shared.request(completion)

        case .fullDiskAccess, .automation, .localNetwork:
            // Unreachable: handled by the canPromptInApp guard above. Kept for
            // exhaustiveness.
            SystemSettingsLink.open(permission)
            completion(status(for: permission))
        }
    }

    /// Returns `true` when the permission's **mandatory** Info.plist usage string is
    /// present (or none is needed). If a required key is missing, requesting would
    /// crash the host — so fail gracefully: assert in debug, complete `.notDetermined`.
    @MainActor
    private static func ensureUsageDescription(
        for permission: Permission,
        completion: @escaping (PermissionStatus) -> Void
    ) -> Bool {
        guard let key = permission.requiredInfoPlistKey else { return true }
        if Bundle.main.object(forInfoDictionaryKey: key) == nil {
            assertionFailure(
                "PermissionPilot: missing \(key) in Info.plist — \(permission.rawValue) cannot be requested without it."
            )
            completion(.notDetermined)
            return false
        }
        return true
    }

    @MainActor
    private static func requestMedia(
        _ permission: Permission,
        _ mediaType: AVMediaType,
        completion: @escaping (PermissionStatus) -> Void
    ) {
        let current = AVCaptureDevice.authorizationStatus(for: mediaType)
        if current == .notDetermined {
            // First time only: a true one-time system prompt can grant in place.
            AVCaptureDevice.requestAccess(for: mediaType) { granted in
                DispatchQueue.main.async { completion(granted ? .granted : .denied) }
            }
        } else {
            // Already decided — the OS won't prompt again, so route to System Settings.
            SystemSettingsLink.open(permission)
            completion(PermissionStatus.from(current))
        }
    }

    @MainActor
    private static func requestContacts(completion: @escaping (PermissionStatus) -> Void) {
        let current = CNContactStore.authorizationStatus(for: .contacts)
        guard current == .notDetermined else {
            SystemSettingsLink.open(.contacts)
            completion(.from(current))
            return
        }
        CNContactStore().requestAccess(for: .contacts) { _, _ in
            DispatchQueue.main.async {
                completion(.from(CNContactStore.authorizationStatus(for: .contacts)))
            }
        }
    }

    @MainActor
    private static func requestPhotos(completion: @escaping (PermissionStatus) -> Void) {
        let current = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard current == .notDetermined else {
            SystemSettingsLink.open(.photos)
            completion(.from(current))
            return
        }
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
            DispatchQueue.main.async { completion(.from(status)) }
        }
    }

    @MainActor
    private static func requestSpeech(completion: @escaping (PermissionStatus) -> Void) {
        let current = SFSpeechRecognizer.authorizationStatus()
        guard current == .notDetermined else {
            SystemSettingsLink.open(.speechRecognition)
            completion(.from(current))
            return
        }
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async { completion(.from(status)) }
        }
    }

    /// EventKit calendars/reminders. macOS 14+ uses the full-access request; earlier
    /// uses the legacy one. We re-read the status in the handler so write-only (14+)
    /// is captured correctly.
    @MainActor
    private static func requestEventKit(
        _ permission: Permission,
        _ entity: EKEntityType,
        completion: @escaping (PermissionStatus) -> Void
    ) {
        let current = EKEventStore.authorizationStatus(for: entity)
        guard current == .notDetermined else {
            SystemSettingsLink.open(permission)
            completion(.from(current))
            return
        }
        // EventKit's request completions are `@Sendable`; bridge the store +
        // non-Sendable completion across it. The handler runs once, serially, and
        // hops to main — so the unchecked wrapper is safe. The box also keeps the
        // store alive until the callback fires.
        let box = PPUncheckedSendable((store: EKEventStore(), completion: completion))
        let handler: @Sendable (Bool, Error?) -> Void = { _, _ in
            DispatchQueue.main.async {
                let (store, completion) = box.value
                completion(.from(EKEventStore.authorizationStatus(for: entity)))
                _ = store
            }
        }
        if #available(macOS 14.0, *) {
            if entity == .reminder {
                box.value.store.requestFullAccessToReminders(completion: handler)
            } else {
                box.value.store.requestFullAccessToEvents(completion: handler)
            }
        } else {
            box.value.store.requestAccess(to: entity, completion: handler)
        }
    }
}

/// Wraps a value so it can cross a `@Sendable` boundary where we've reasoned the
/// access is safe (the callback runs once, serially, and we hop to the main thread).
private final class PPUncheckedSendable<Value>: @unchecked Sendable {
    let value: Value
    init(_ value: Value) { self.value = value }
}
